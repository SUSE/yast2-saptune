# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016-2021 SUSE LLC.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 3 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
# Author: Howard Guo <hguo@suse.com>

require 'yast'
require 'open3'

Yast.import 'Service'

module Saptune
    # A smart sysconfig file editor that not only can handle key-value but also arrays.
    # Array is identified by a key with _{number} suffix.
    class SysconfigEditor
        def initialize(text)
            @lines = text.b.split("\n")
        end

        # Return all keys.
        # If a key represents an array, then the key (rather than every index of it) will be returned.
        def keys
            ret = []
            scan(/.*/) { | key, idx, val|
                if idx == :nil || idx == 0
                    ret << key
                end
                [:continue]
            }
            return ret
        end

        # Return value, or empty string if the key does not exist.
        # Calling this function on an array key will return an empty string.
        def get(key)
            ret = ''
            scan(/^#{key}$/) { |_, idx, val|
                if idx == :nil
                    ret = val
                    [:stop]
                else
                    [:continue]
                end
            }
            return ret
        end

        # Set value or create the key if it does not exist. Return true only if the key was found.
        def set(key, val)
            found = false
            scan(/^#{key}$/) { |_, _, _|
                found = true
                [:set, val]
            }
            if !found
                @lines << "#{key}=\"#{val}\""
            end
            return found
        end

        # Return length of array represented by the key.
        # Return 0 if the key does not exist.
        def array_len(key)
            # By contract an array key must use an underscore before index number
            max_idx = -1
            scan(/^#{key}_*$/) { |_, idx, _|
                if idx != nil && idx > max_idx
                    max_idx = idx
                end
                [:continue]
            }
            return max_idx + 1
        end

        # Return array value that corresponds to the key and index.
        # Return empty string if the key does not exist, or the index does not exist/out of bound.
        def array_get(key, index)
            ret = ''
            scan(/^#{key}_*$/) { |_, idx, val|
                if idx == index
                    ret = val
                    [:stop]
                else
                    [:continue]
                end
            }
            return ret
        end

        # Set array value or create the key/index if it does not exist. Return true only if index was found.
        def array_set(key, index, val)
            found = false
            scan(/^#{key}_*$/) { |_, idx, _|
                if idx == index
                    found = true
                    [:set, val]
                else
                    [:continue]
                end
            }
            if !found
                @lines << "#{key}_#{index}=\"#{val}\""
            end
            return found
        end

        # Shrikn or enlarge the array to match the specified length.
        # If specified length is 0, the entire array is erased.
        def array_resize(key, new_len)
            seen_idx = -1
            scan(/^#{key}_*$/) { |_, idx, val|
                if idx == nil
                    [:continue]
                elsif idx >= new_len
                    if idx - 1 > seen_idx
                        seen_idx = idx - 1
                    end
                    # Remove excesive indexes
                    [:delete_continue]
                else
                    seen_idx = idx
                end
            }
            # Introduce extra indexes
            (seen_idx+1..new_len-1).each{ |idx|
                @lines << "#{key}_#{idx}=\"\""
            }
        end

        # Produce sysconfig file text, including all the modifications that have been done.
        def to_text
            return @lines.join("\n") + "\n"
        end

        # Scan all lines looking for keys matching the specified regex.
        # Call code block with three parameters:
        # - key without index number
        # - index number, :nil if not an array
        # - value
        # Code block is expected to return an array:
        # [:stop] - stop scanning and end
        # [:continue] - continue scanning
        # [:delete_stop] - delete the key (or array element) and stop
        # [:delete_continue] - delete the key (or array element) and continue
        # [:set, $new_value] - update the value (or array element value) and stop
        def scan(key_regex, &block)
            to_delete_idx = []
            (0..@lines.length-1).each { |idx|
                line = @lines[idx].strip
                param = nil
                # Test against array key
                array_kiv = /^([A-Za-z0-9_]+)_([0-9])+="?([^"]*)"?$/.match(line)
                if array_kiv != nil
                    param = [array_kiv[1], array_kiv[2].to_i, array_kiv[3]]
                else
                    # Test against ordinary key
                    kv = /^([A-Za-z0-9_]+)="?([^"]*)"?$/.match(line)
                    if kv != nil
                        param = [kv[1], :nil, kv[2]]
                    end
                end
                if param != nil && key_regex.match(param[0])
                    # Invoke code block and act upon the result
                    result = block.call(*param)
                    case result[0]
                        when :stop
                            break
                        when :continue
                            next
                        when :delete_stop
                            to_delete_idx << idx
                            break
                        when :delete_continue
                            to_delete_idx << idx
                            next
                        when :set
                            if array_kiv == nil
                                @lines[idx] = "#{param[0]}=\"#{result[1]}\""
                            else
                                @lines[idx] = "#{param[0]}_#{param[1]}=\"#{result[1]}\""
                            end
                            break
                    end
                end
            }
            to_delete_idx.reverse.each {|idx|
                @lines.slice!(idx)
            }
        end
    end

    # Manipulate sapconf and saptune services.
    class SaptuneConf
        include Yast::I18n
        include Yast::Logger

        def initialize
            textdomain 'saptune'
        end

        # Call saptune (external program) with the specified parameters, return and log combined stdout/stderr output and exit status.
        def call_saptune_and_log(*params)
            begin
                out, status = Open3.capture2e('saptune', *params)
                log.info "saptune command - #{params.join(' ')}: #{status} #{out}"
                return out, status.exitstatus
            rescue Errno::ENOENT
                log.error 'saptune command does not exist'
                return '', 127
            end
        end

        # Call sapconf (external program) with the specified parameters, return and log combined stdout/stderr output and exit status.
        def call_sapconf_and_log(*params)
            begin
                out, status = Open3.capture2e('sapconf', *params)
                log.info "sapconf command - #{params.join(' ')}: #{status} #{out}"
                return out, status.exitstatus
            rescue Errno::ENOENT
                log.error 'sapconf command does not exist'
                return '', 127
            end
        end

        # Call systemctl (external program) to find out, if a service is enabled
        def is_service_enabled
            if is_new_saptune_vers
                service = "saptune.service"
            else
                service = "tuned.service"
            end
            out, status = Open3.capture2e('systemctl', 'is-enabled', service)
            log.info "systemctl is-enabled #{service}: #{status} #{out}"
            if status.exitstatus == 0
                return true
            else
                return false
            end
        end

        # Return status of saptune:
        # :ok - saptune is running and tuning has been done
        # :stopped - saptune's service (saptune.service) is stopped
        # :not_tuned - saptune has no applied notes
        # :no_conf - saptune is not configured (saptune is not the tuned profile)
        def state
            if is_new_saptune_vers
                _, status = call_saptune_and_log('service', 'status')
            else
                _, status = call_saptune_and_log('daemon', 'status')
            end
            if status == 0
                return :ok
            elsif status == 1
                return :stopped
            elsif status == 2
                return :no_conf
            elsif status == 3
                return :not_tuned
            else
                return :unknown
            end
        end

        # Enable+start or disable+stop saptune and its service (saptune.service).
        # It may take up to a minute to enable+start the serice.
        # Return boolean status and debug output (only in error case).
        # Boolean status is true only if the operation is carried out successfully.
        def set_state(enable)
            if enable
                disable_sapconf
                if is_new_saptune_vers
                    out, status = call_saptune_and_log('service', 'takeover')
                else
                    out, status = call_saptune_and_log('daemon', 'start')
                end
                if status != 0
                    return false, out
                end
            else
                if is_new_saptune_vers
                    out, status = call_saptune_and_log('service', 'disablestop')
                else
                    out, status = call_saptune_and_log('daemon', 'stop')
                end
                if status != 0
                    return false, out
                end
            end
            return true, ''
        end

        # Look for SAP systems that are currently installed on the computer, return a tuple of two booleans.
        # The first boolean is true only if Netweaver product is installed.
        # The second boolean is true only if HANA database is installed.
        def is_sap_installed
            has_nw = ['log', 'data', 'work', 'exe'].all?{|name| Dir.glob("/usr/sap/*/#{name}").any?}
            has_hana = Dir.glob('/usr/sap/*/HDB*/HDB').any?
            return [has_nw, has_hana]
        end

        # Look, if saptune version >= 3 is installed
        def is_new_saptune_vers
            path_workarea = '/var/lib/saptune/working/notes'
            if !File.exists?(path_workarea)
                return false
            end
            return true
        end

        # Return true only if sapconf is presently used, and its configuration has never deviated from default.
        # (i.e. saptune can completely replace sapconf)
        def can_replace_sapconf
            path_current = '/etc/sysconfig/sapconf'
            path_original = '/var/adm/fillup-templates/sysconfig.sapconf'
            if !File.exists?(path_original)
                path_original = '/usr/share/fillup-templates/sysconfig.sapconf'
            end
            if !File.exists?(path_current) || !File.exists?(path_original)
                return true
            end
            # Compare all key-value pairs
            current = Saptune::SysconfigEditor.new(IO.read(path_current))
            original = Saptune::SysconfigEditor.new(IO.read(path_original))
            conf_current = {}
            current.scan(/.*/) { |key, idx, val|
                conf_current[idx.to_s + key] = val
            }
            conf_original = {}
            original.scan(/.*/) { |key, idx, val|
                conf_original[idx.to_s + key] = val
            }
            return conf_current == conf_original
        end

        def disable_sapconf
            out, status = Open3.capture2e('systemctl', 'stop', 'sapconf.service')
            if status.exitstatus != 0
                log.info('Failed to stop sapconf: ' + out)
            end
            out, status = Open3.capture2e('systemctl', 'disable', 'sapconf.service')
            if status.exitstatus != 0
                log.info('Failed to disable sapconf: ' + out)
            end
        end

        # If sapconf has been configured, tell sapconf to start.
        # If sapconf is not installed, or if the configuration is not customisd, proceed to set up saptune.
        # saptune will be activated and told to tune for HANA or Netweaver or both, depending on their presence on this computer..
        # Return an array of:
        # - boolean - true only if NW is tuned for
        # - boolean - true only if HANA is tuned for
        # - boolean - true only if tuning is successfully activated
        # - string - error message if there is any
        def auto_config
            has_nw, has_hana = is_sap_installed

            if can_replace_sapconf
                disable_sapconf
                # revert settings first before add the new one.
                out, status = call_saptune_and_log('revert', 'all')
                log.info 'tuning system using saptune'
                if has_nw && has_hana
                    path_solution = '/usr/share/saptune/solutions'
                    if !File.exists?(path_solution)
                        # old saptune - apply both solutions
                        out, status = call_saptune_and_log('solution', 'apply', 'NETWEAVER')
                        if status != 0
                            return has_nw, has_hana, false, out
                        end
                        out, status = call_saptune_and_log('solution', 'apply', 'HANA')
                        if status != 0
                            return has_nw, has_hana, false, out
                        end
                    else
                        # new saptune - only one solution possible
                        out, status = call_saptune_and_log('solution', 'apply', 'NETWEAVER+HANA')
                        if status != 0
                            return has_nw, has_hana, false, out
                        end
                    end
                end
                if has_nw && !has_hana
                    out, status = call_saptune_and_log('solution', 'apply', 'NETWEAVER')
                    if status != 0
                        return has_nw, has_hana, false, out
                    end
                end
                if has_hana && !has_nw
                    out, status = call_saptune_and_log('solution', 'apply', 'HANA')
                    if status != 0
                        return has_nw, has_hana, false, out
                    end
                end
                if is_new_saptune_vers
                    out, status = call_saptune_and_log('service', 'takeover')
                else
                    out, status = call_saptune_and_log('daemon', 'start')
                end
                return has_nw, has_hana, status == 0, out
            end

            log.info 'tuning system using sapconf'
            if has_nw
                out, status = call_sapconf_and_log('netweaver')
                if status != 0
                    return has_nw, has_hana, false, out
                end
            end
            if has_hana
                out, status = call_sapconf_and_log('hana')
                if status != 0
                    return has_nw, has_hana, false, out
                end
            end
            if !has_hana && !has_nw
                # start sapconf with the last active profile
                out, status = call_sapconf_and_log('start')
                if status != 0
                    return has_nw, has_hana, false, out
                end
            end
            return has_nw, has_hana, true, ''
        end
    end
    SaptuneConfInst = SaptuneConf.new

    # Hold autoyast-specific state information and bridge the action between autoyast and SaptuneConf.
    class SaptuneAutoconf
        include Yast::I18n
        include Yast::Logger

        def initialize
            textdomain 'saptune'
            @enable = false
        end

        # If @enable is true, automatically configure saptune and enable it.
        # Otherwise, disable saptune.
        # Return tuple of boolean status and command output (only in error case).
        # Boolean status is true only if all operations are carried out successfully.
        def apply
            if @enable
                return SaptuneConfInst.auto_config # by contract, auto_config also enables saptune
            end
            return SaptuneConfInst.set_state(false)
        end

        attr_accessor(:enable)
    end
    SaptuneAutoconfInst = SaptuneAutoconf.new
end

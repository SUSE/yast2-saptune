# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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
require 'saptune/saptune_conf'
require 'saptuneui/auto_main_dialog'
require 'installation/auto_client'

module Saptune
    # Automatically generate configuration for saptune and activate it.
    class AutoClient < Installation::AutoClient
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            super
            textdomain 'saptune'
        end

        def run
            progress_orig = Progress.set(false)
            ret = super
            Progress.set(progress_orig)
            ret
        end

        # There is only one bool parameter to import.
        def import(exported)
            SaptuneAutoconfInst.enable = exported['enable']
            return true
        end

        # There is only one bool parameter to export.
        def export
            return {'enable' => SaptuneAutoconfInst.enable}
        end

        # Insignificant to autoyast.
        def modified?
            return true
        end

        # Insignificant to autoyast.
        def modified
            return
        end

        # Return a readable text summary.
        def summary
            if SaptuneAutoconfInst.enable
                return _('SAP system tuning will be enabled, and configured automatically according to installed SAP softwares.')
            else
                return _('SAP system tuning is not enabled.')
            end
        end

        # Display dialog to let user turn saptune on/off.
        def change
            AutoMainDialog.new.run
            return :finish
        end

        # Read the status of saptune on this system and memorise it as autoyast state.
        def read
            SaptuneAutoconfInst.enable = SaptuneConfInst.state == :ok || SaptuneConfInst.state == :no_conf
            return true
        end

        # If saptune should be enabled, automatically configure it and enable it. Otherwise disable it.
        def write
            success, out = SaptuneAutoconfInst.apply
            log.info "Saptune::AutoClient.write: success #{success} output #{out}"
            return success
        end

        # Set saptune to "to be disabled".
        def reset
            SaptuneAutoconfInst.enable = false
            return true
        end

        # Return package dependencies, as of now saptune is the only one.
        def packages
            return {'install' => ['saptune'], 'remove' => []}
        end
    end
end

Saptune::AutoClient.new.run

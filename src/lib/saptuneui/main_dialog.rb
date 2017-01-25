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
require 'ui/dialog'
require 'saptune/saptune_conf'
Yast.import 'UI'
Yast.import 'Icon'
Yast.import 'Label'
Yast.import 'Popup'
Yast.import 'Package'

module Saptune
    # Main dialog allows user to enable (and auto-configure) or disable saptune.
    class MainDialog
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            textdomain 'saptune'
        end

        def run
            # Render the dialog
            UI.OpenDialog(Opt(:decoreated, :defaultsize), VBox(
                Left(HBox(
                    Icon::Simple('yast-sysconfig'),
                    Heading(_('saptune configuration')),
                )),
                VSpacing(1),
                MinWidth(50, Frame(_('Status'), HSquash(HBox(
                    VBox(
                        Left(Label(_('Daemon Status'))),
                        Left(Label(_('Configuration Status'))),
                    ),
                    VBox(
                        Left(Label(Id(:daemon_status), '')),
                        Left(Label(Id(:config_status), '')),
                    ),
                )))),
                VSpacing(1),
                MinWidth(50, Frame(_('Action'), HSquash(RadioButtonGroup(Id(:action), VBox(
                    Left(RadioButton(Id(:genconf), '')),
                    Left(RadioButton(Id(:daemon_toggle), '')),
                ))))),
                VSpacing(1),
                Label(_('saptune comprehensively manages system optimisations for SAP solutions.')),
                Label(_('To further customise saptune, please consult manual page of saptune.')),
                VSpacing(1),
                ReplacePoint(Id(:busy), Empty()),
                ButtonBox(
                    PushButton(Id(:ok), Label.OKButton),
                    PushButton(Id(:cancel), Label.CancelButton),
                ),
            ))
            case SaptuneConfInst.state
                when :ok
                    UI.ChangeWidget(Id(:daemon_status), :Label, _('Running'))
                    UI.ChangeWidget(Id(:config_status), :Label, _('Present'))
                    UI.ChangeWidget(Id(:genconf), :Label, _('Re-generate configuration'))
                    UI.ChangeWidget(Id(:daemon_toggle), :Label, _('Disable and stop the daemon'))
                when :stopped
                    UI.ChangeWidget(Id(:daemon_status), :Label, _('Not Running'))
                    UI.ChangeWidget(Id(:config_status), :Label, _('Unknown'))
                    UI.ChangeWidget(Id(:genconf), :Label, _('Re-generate configuration and enable the daemon'))
                    UI.ChangeWidget(Id(:daemon_toggle), :Label, _('Enable and start the daemon'))
                when :no_conf
                    UI.ChangeWidget(Id(:daemon_status), :Label, _('Running'))
                    UI.ChangeWidget(Id(:config_status), :Label, _('Absent'))
                    UI.ChangeWidget(Id(:genconf), :Label, _('Generate configuration automatically'))
                    UI.ChangeWidget(Id(:daemon_toggle), :Label, _('Disable and stop the daemon'))
            end
            UI.RecalcLayout

            # Prompt to disable sapconf
            if !SaptuneConfInst.can_replace_sapconf
                Popup.Error(_('Your system is currently configured to use the legacy sapconf.
saptune is a powerful replacement for sapconf, please erase sapconf package before using this module.'))
                return :finish_dialog
            end

            # Install saptune package
            package_present = Package.Installed('saptune')
            if !package_present && Popup.YesNo(_('saptune comprehensively manages system optimisations for SAP solutions.
Would you like to install and use it now?')) && Package.DoInstall(['saptune'])
                package_present = true
            end
            if !package_present
                return :finish_dialog
            end

            # Begin the event loop
            begin
                event_loop
            ensure
                UI.CloseDialog
            end
            return :finish_dialog
        end

        def event_loop
            loop do
                case UI.UserInput
                    when :ok
                        UI.ReplaceWidget(Id(:busy), Label(Id(:busy_ind), _('Applying settings, this may take several seconds...')))
                        case UI.QueryWidget(Id(:action), :CurrentButton)
                            when :genconf
                                nw, hana, success, out = SaptuneConfInst.auto_config
                                if success
                                    if !hana && !nw
                                        Popup.Message(_('Cannot find a compatible installed SAP software to tune for, only generic performance tuning is performed.'))
                                    else
                                        prods = ''
                                        prods += "- SAP Netweaver\n" if nw
                                        prods += "- SAP HANA\n" if hana
                                        Popup.AnyMessage(_('Success'), _("saptune has been activated and system is now tuned for:\n") + prods)
                                    end

                                else
                                    Popup.ErrorDetails(_('Failed to apply new configuration'), _('Error output: ') + out)
                                end
                            when :daemon_toggle
                                case SaptuneConfInst.state
                                    when :ok
                                        success, out = SaptuneConfInst.set_state(false)
                                        if success
                                            Popup.AnyMessage(_('Success'), _('saptune is now disabled.'))
                                        else
                                            Popup.ErrorDetails(_('Failed to disable saptune'), _('Error output: ') + out)
                                        end
                                    when :stopped, :no_conf
                                        success, out = SaptuneConfInst.set_state(true)
                                        if success
                                            Popup.AnyMessage(_('Success'), _('saptune is now enabled.'))
                                        else
                                            Popup.ErrorDetails(_('Failed to enablesaptune'), _('Error output: ') + out)
                                        end
                                end
                        end
                        return
                    else
                        return
                end
            end
        end
    end
end

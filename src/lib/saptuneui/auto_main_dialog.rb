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

module Saptune
    # AutoYast main dialog allows user to enable (with auto-config) or disable saptune.
    class AutoMainDialog < UI::Dialog
        include Yast
        include UIShortcuts
        include I18n
        include Logger

        def initialize
            super
            textdomain 'saptune'
        end

        def create_dialog
            return super
        end

        def dialog_options
            Opt(:decoreated, :defaultsize)
        end

        def dialog_content
            VBox(
                Left(HBox(
                    Icon::Simple('yast-sysconfig'),
                    Heading(_('saptune configuration')),
                )),
                VSpacing(1),
                MinWidth(50, Frame(_('Action'), HSquash(RadioButtonGroup(Id(:action), VBox(
                    Left(RadioButton(Id(:enable), 'Automatically generate configuration and enable saptune.', SaptuneAutoconfInst.enable)),
                    Left(RadioButton(Id(:disable), 'Do not use saptune.', !SaptuneAutoconfInst.enable)),
                ))))),
                VSpacing(1),
                Label(_('saptune comprehensively manages system optimisations for SAP solutions')),
                Label(_('To further customise saptune, please consult manual page "man 8 saptune".')),
                VSpacing(1),
                ButtonBox(
                    PushButton(Id(:ok), Label.OKButton),
                    PushButton(Id(:cancel), Label.CancelButton),
                ),
            )
        end

        def ok_handler
            SaptuneAutoconfInst.enable = UI.QueryWidget(Id(:action), :CurrentButton) == :enable
            finish_dialog(:finish)
        end

        def cancel_handler
            finish_dialog(:finish)
        end
    end
end

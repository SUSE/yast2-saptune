#!/usr/bin/env rspec
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
#
# Authors: Howard Guo <hguo@suse.com>

ENV['Y2DIR'] = File.expand_path('../../src', __FILE__)

require 'yast'
require 'yast/rspec'
require 'saptune/saptune_conf'

include Yast
include Saptune

# Since the test cases are not run by user root, nor do they run on real SAP systems,
# these tests will only ensure that the test subjects do not crash.
describe SaptuneConfInst do
    it '.call_saptune_and_log' do
        out, status = SaptuneConfInst.call_saptune_and_log('foo', 'bar')
        expect(status).to be > 0
    end

    it '.state' do
        expect(SaptuneConfInst.state).to eq(:unknown)
    end

    it '.set_state' do
        # Test cases do not run as user root
        success, _ = SaptuneConfInst.set_state(true)
        expect(success).to eq(false)
    end

    it '.is_sap_installed' do
        # Test cases do not run on real SAP systems
        expect(SaptuneConfInst.is_sap_installed).to eq([false, false])
    end

    it '.auto_config' do
        # Test cases do not run on reall SAP systems, hence the function cannot activate saptune.
        success, _ = SaptuneConfInst.auto_config
        expect(success).to eq(false)
    end
end

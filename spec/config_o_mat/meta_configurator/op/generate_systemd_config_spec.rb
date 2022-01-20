# frozen_string_literal: true

# Copyright 2021 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'config_o_mat/meta_configurator/op/generate_systemd_config'

require 'config_o_mat/meta_configurator/memory'
require 'config_o_mat/shared/systemd_interface'
require 'config_o_mat/shared/types'

require 'tmpdir'

RSpec.describe ConfigOMat::Op::GenerateSystemdConfig do
  def perform
    described_class.call(state)
  end

  before do
    @systemd_directory = Dir.mktmpdir
    @result = perform
  end

  after do
    FileUtils.remove_entry @systemd_directory
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::MetaConfigurator::Memory.new(
      template_defs: template_defs,
      service_defs: service_defs,
      runtime_directory: runtime_directory,
      systemd_directory: systemd_directory,
      systemd_interface: systemd_interface
    )
  end

  let(:template_defs) do
    {
      templ0: ConfigOMat::Template.new(src: 'foo.conf', dst: 'foo.conf'),
      templ1: ConfigOMat::Template.new(src: 'bar.conf', dst: 'bar.conf')
    }
  end

  let(:service_defs) do
    {
      test0: ConfigOMat::Service.new(
        systemd_unit: 'test0', restart_mode: restart_mode, templates: [
          'templ0', 'templ1'
        ]
      ),
      test1: ConfigOMat::Service.new(
        systemd_unit: 'test1', restart_mode: restart_mode, templates: [
          'templ0'
        ]
      )
    }
  end

  let(:systemd_directory) { @systemd_directory }
  let(:runtime_directory) { '/somewhere/else' }
  let(:systemd_interface) do
    instance_double("SystemdInterface").tap do |iface|
      allow(iface).to receive(:enable_restart_paths).and_return(nil)
      allow(iface).to receive(:enable_start_stop_paths).and_return(nil)
      allow(iface).to receive(:daemon_reload).and_return(nil)
    end
  end

  context 'with restart_mode=restart' do
    let(:restart_mode) { 'restart' }

    it 'enables restart paths for each service' do
      expect(systemd_interface).to have_received(:enable_restart_paths).with(['test0', 'test1'])
    end

    it 'outputs additional configuration' do
      expect(File.read(File.join(systemd_directory, 'test0.service.d/99_teak_configurator.conf'))).to include(
        %([Service]\nLoadCredential=foo.conf:#{runtime_directory}/foo.conf\nLoadCredential=bar.conf:#{runtime_directory}/bar.conf)
      )
      expect(File.read(File.join(systemd_directory, 'test1.service.d/99_teak_configurator.conf'))).to include(
        %([Service]\nLoadCredential=foo.conf:#{runtime_directory}/foo.conf)
      )
    end

    it 'reloads the daemon' do
      expect(systemd_interface).to have_received(:daemon_reload)
    end
  end

  context 'with restart_mode=flip_flop' do
    let(:restart_mode) { 'flip_flop' }

    it 'enables start and stop paths for each service' do
      expect(systemd_interface).to have_received(:enable_start_stop_paths).with(['test0@1', 'test0@2', 'test1@1', 'test1@2'])
    end

    it 'outputs additional configuration' do
      expect(File.read(File.join(systemd_directory, 'test0@.service.d/99_teak_configurator.conf'))).to include(
        %([Service]\nLoadCredential=foo.conf:#{runtime_directory}/foo.conf\nLoadCredential=bar.conf:#{runtime_directory}/bar.conf)
      )
      expect(File.read(File.join(systemd_directory, 'test1@.service.d/99_teak_configurator.conf'))).to include(
        %([Service]\nLoadCredential=foo.conf:#{runtime_directory}/foo.conf)
      )
    end

    it 'reloads the daemon' do
      expect(systemd_interface).to have_received(:daemon_reload)
    end
  end
end

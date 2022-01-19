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

require 'op/reload_one_service'

require 'configurator_memory'
require 'configurator_types'
require 'meta_configurator_types'

require 'logsformyfamily'

require 'tmpdir'

RSpec.describe Op::ReloadOneService do
  def perform
    described_class.call(state)
  end

  before do
    allow(FlipFlopper).to receive(:new).and_return(flip_flop_stub)

    @runtime_directory = Dir.mktmpdir
    touch_files.each do |file|
      path = File.join(runtime_directory, file)
      FileUtils.touch(path)
      @stat ||= {}
      @stat[file] = File.stat(path)
    end
    @result = perform
  end

  after do
    FileUtils.remove_entry @runtime_directory
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      runtime_directory: runtime_directory,
      service_defs: service_defs,
      services_to_reload: services_to_reload,
      logger: logger,
      systemd_interface: systemd_interface
    )
  end

  let(:runtime_directory) { @runtime_directory }
  let(:service_defs) do
    {
      service0: Service.new(systemd_unit: 'test', restart_mode: restart_mode, templates: ['templ0']),
      service1: Service.new(systemd_unit: 'other', restart_mode: restart_mode, templates: ['templ1'])
    }
  end

  let(:services_to_reload) { %i[service0 service1] }
  let(:touch_files) { [] }
  let(:logger) { nil }
  let(:flip_flop_stub) { nil }
  let(:systemd_interface) do
    SystemdInterface.new({
      SystemdInterface::SERVICE_NAME => {
        SystemdInterface::OBJECT_PATH => {
          SystemdInterface::MANAGER_INTERFACE => {}
        }
      }
    })
  end

  context 'when restart_mode=restart' do
    let(:restart_mode) { 'restart' }

    context 'without a reload file present' do
      it 'touches the reload file' do
        expect { File.stat(File.join(runtime_directory, 'other.restart')) }.not_to raise_error
      end

      it 'updates services_to_reload' do
        expect(state).to have_attributes(
          services_to_reload: %i[service0]
        )
      end
    end

    context 'with a reload file present' do
      let(:touch_files) { ['other.restart'] }

      it 'touches the reload file' do
        expect(File.stat(File.join(runtime_directory, 'other.restart'))).to be > @stat['other.restart']
      end

      it 'updates services_to_reload' do
        expect(state).to have_attributes(
          services_to_reload: %i[service0]
        )
      end
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs a service reload' do
        expect(@messages).to include(
          contain_exactly(:notice, :service_restart, a_hash_including(name: :service1, systemd_unit: 'other'))
        )
      end
    end
  end

  context 'when restart_mode=flip_flop' do
    let(:restart_mode) { 'flip_flop' }

    let(:flip_flop_stub) do
      instance_double(FlipFlopper).tap do |vm|
        allow(vm).to receive(:call).and_return(vm)
        allow(vm).to receive(:errors?).and_return(!flip_flop_errors.nil?)
        allow(vm).to receive(:errors).and_return(flip_flop_errors)
      end
    end

    let(:flip_flop_errors) { nil }

    let(:logger) do
      @messages = []
      l = LogsForMyFamily::Logger.new
      l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
      l
    end

    it 'creates a flip flopper vm with proper memory' do
      expect(FlipFlopper).to have_received(:new).with(
        have_attributes(
          systemd_interface: systemd_interface,
          service: 'other@',
          runtime_directory: runtime_directory,
          logger: logger
        )
      )
    end

    it 'executes the flip flopper vm' do
      expect(flip_flop_stub).to have_received(:call)
    end

    it 'updates services_to_reload' do
      expect(state).to have_attributes(
        services_to_reload: %i[service0]
      )
    end

    context 'when the flip flop fails' do
      let(:flip_flop_errors) do
        {
          service: ['failed to start service instance']
        }
      end

      it 'passes along errors' do
        expect(result.errors).to match(
          service: ['failed to start service instance']
        )
      end
    end
  end
end

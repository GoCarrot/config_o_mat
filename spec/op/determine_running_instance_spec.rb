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

require 'op/determine_running_instance'

require 'flip_flop_memory'

RSpec.describe Op::DetermineRunningInstance do
  ACTIVE_STATES = %w[active activating reloading].freeze
  INACTIVE_STATES = %w[inactive failed deactivating].freeze

  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    FlipFlopMemory.new(
      systemd_interface: systemd_interface,
      service: 'test@',
      logger: logger
    )
  end

  let(:systemd_interface) do
    instance_double('SystemdInterface').tap do |iface|
      allow(iface).to receive(:unit_status).with('test@1').and_return(test1_status)
      allow(iface).to receive(:unit_status).with('test@2').and_return(test2_status)
    end
  end

  let(:logger) { nil }

  context 'with a logger' do
    let(:test1_status) { ACTIVE_STATES.sample }
    let(:test2_status) { INACTIVE_STATES.sample }
    let(:logger) do
      @messages = []
      l = LogsForMyFamily::Logger.new
      l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
      l
    end

    it 'logs the status of each instance' do
      expect(@messages).to include(
        contain_exactly(:info, :service_status, a_hash_including(name: 'test@1', status: test1_status)),
        contain_exactly(:info, :service_status, a_hash_including(name: 'test@2', status: test2_status))
      )
    end
  end

  context 'when instance 1 is running' do
    let(:test1_status) { ACTIVE_STATES.sample }

    context 'when instance 2 is not running' do
      let(:test2_status) { INACTIVE_STATES.sample }

      it 'sets running_instance to 1 and activating_instance to 2' do
        expect(state).to have_attributes(
          running_instance: 1,
          activating_instance: 2
        )
      end
    end
  end

  context 'when instance 2 is running' do
    let(:test2_status) { ACTIVE_STATES.sample }

    context 'when instance 1 is not running' do
      let(:test1_status) { INACTIVE_STATES.sample }

      it 'sets running_instance to 2 and activating_instance to 1' do
        expect(state).to have_attributes(
          running_instance: 2,
          activating_instance: 1
        )
      end
    end
  end

  context 'when neither instance is running' do
    let(:test1_status) { INACTIVE_STATES.sample }
    let(:test2_status) { INACTIVE_STATES.sample }

    it 'sets running_instance to 2 and activating_instance to 1' do
      expect(state).to have_attributes(
        running_instance: 2,
        activating_instance: 1
      )
    end
  end

  context 'when both instances are running' do
    let(:test1_status) { ACTIVE_STATES.sample }
    let(:test2_status) { ACTIVE_STATES.sample }

    it 'errors' do
      expect(result.errors).to match(
        service: ['both instances are currently running!']
      )
    end
  end
end

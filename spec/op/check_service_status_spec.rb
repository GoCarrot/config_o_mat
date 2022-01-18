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

require 'op/check_service_status'

require 'flip_flop_memory'

RSpec.describe Op::CheckServiceStatus do
  def perform
    described_class.call(state)
  end

  before do
    allow(Kernel).to receive(:sleep) { |time| time.to_i }
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    FlipFlopMemory.new(
      service: 'test@',
      activating_instance: activating_instance,
      activating_interface: activating_interface,
      systemd_interface: systemd_interface,
      min_wait: min_wait,
      max_wait: max_wait
    )
  end

  let(:activating_instance) { [1, 2].sample }
  let(:min_wait) { 5 }
  let(:max_wait) { 30 }
  let(:activating_interface) { unit_interface_stub }
  let(:unit_status) { 'activating' }

  let(:unit_interface_stub) do
    { 'ActiveStatus' => unit_status }
  end


  let(:systemd_interface) do
    instance_double('SystemdInterface').tap do |iface|
      allow(iface).to receive(:unit_interface).with("test@#{activating_instance}")
                                              .and_return(unit_interface_stub)
    end
  end

  context 'when activating_interface is nil' do
    let(:activating_interface) { nil }

    context 'when a unit interface cannot be loaded' do
      let(:unit_interface_stub) { nil }

      it 'sets activation_status to failed' do
        expect(state.activation_status).to eq :failed
      end
    end

    context 'when a unit interface is loaded' do
      it 'saves the unit interface' do
        expect(state.activating_interface).to be unit_interface_stub
      end
    end
  end

  context 'when min_wait is > 0' do
    it 'sleeps for min_wait' do
      expect(Kernel).to have_received(:sleep).with(min_wait)
    end

    it 'updates min_wait and max_wait' do
      expect(state).to have_attributes(
        min_wait: 0,
        max_wait: max_wait - min_wait
      )
    end
  end

  context 'when min_wait is <= 0' do
    let(:min_wait) { 0 }

    it 'sleeps for one second' do
      expect(Kernel).to have_received(:sleep).with(1)
    end

    it 'updates max_wait' do
      expect(state.max_wait).to eq max_wait - 1
    end
  end

  context 'when the unit is active' do
    let(:unit_status) { 'active' }

    it 'sets activation_status to started' do
      expect(state.activation_status).to eq :started
    end

    context 'when max_wait is up' do
      let(:max_wait) { 1 }

      it 'sets activation_status to started' do
        expect(state.activation_status).to eq :started
      end
    end
  end

  context 'when the unit is activating' do
    context 'when max_wait is > 0' do
      it 'sets activation_status to starting' do
        expect(state.activation_status).to eq :starting
      end
    end

    context 'when max_wait is up' do
      let(:max_wait) { 1 }

      it 'sets activation_status to timed_out' do
        expect(state.activation_status).to eq :timed_out
      end
    end
  end

  context 'when the unit is in any other state' do
    let(:unit_status) { %w[inactive failed reloading deactivating].sample }

    it 'sets activation_status to failed' do
      expect(state.activation_status).to eq :failed
    end
  end
end

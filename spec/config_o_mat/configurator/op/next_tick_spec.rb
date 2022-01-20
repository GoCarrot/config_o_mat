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

require 'config_o_mat/configurator/op/next_tick'

require 'config_o_mat/configurator/memory'

RSpec.describe ConfigOMat::Op::NextTick do
  def perform
    described_class.call(state)
  end

  before do
    @notifier = class_double('SdNotify').as_stubbed_const(transfer_nested_constants: true)
    allow(@notifier).to receive(:watchdog)
    allow(Kernel).to receive(:sleep) { |time| time.to_i }
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      last_refresh_time: last_refresh_time,
      refresh_interval: refresh_interval,
      run_count: run_count,
      retry_count: retry_count,
      retries_left: retries_left
    )
  end

  let(:last_refresh_time) { Time.now.to_i }
  let(:refresh_interval) { 5 }
  let(:run_count) { rand(1_000_000) }
  let(:retry_count) { 42 }
  let(:retries_left) { 5 }

  context "when we aren't due to refresh profiles" do
    it 'sleeps' do
      expect(Kernel).to have_received(:sleep).with(be > 0)
    end

    it 'updates state and proceeds to running' do
      expect(state).to have_attributes(
        next_state: :running,
        run_count: run_count + 1,
        retries_left: retry_count
      )
    end

    it 'notifies the systemd watchdog timer' do
      expect(@notifier).to have_received(:watchdog)
    end
  end

  context "when we are due to refresh profiles" do
    let(:last_refresh_time) { Time.now.to_i - (refresh_interval + 1) }

    it 'sleeps' do
      expect(Kernel).to have_received(:sleep).with(be > 0)
    end

    it 'updates state and proceeds to refreshing_profiles' do
      expect(state).to have_attributes(
        next_state: :refreshing_profiles,
        run_count: run_count + 1,
        retries_left: retry_count
      )
    end

    it 'notifies the systemd watchdog timer' do
      expect(@notifier).to have_received(:watchdog)
    end
  end
end

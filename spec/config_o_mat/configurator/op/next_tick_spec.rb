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
    allow(GC).to receive(:compact).and_return({did: :thing})
    allow(GC).to receive(:stat).and_return({some: :stats})
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      last_refresh_time: last_refresh_time,
      refresh_interval: refresh_interval,
      run_count: run_count,
      retry_count: retry_count,
      retries_left: retries_left,
      gc_stat: gc_stat,
      gc_compact: gc_compact,
      logger: logger
    )
  end

  let(:last_refresh_time) { Time.now.to_i }
  let(:refresh_interval) { 5 }
  let(:run_count) { rand(1_000_000) }
  let(:retry_count) { 42 }
  let(:retries_left) { 5 }
  let(:gc_stat) { 0 }
  let(:gc_compact) { 0 }
  let(:logger) { nil }

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

  context 'when gc_stat is >= 0' do
    let(:gc_stat) { 60 }

    context 'when it has not been gc_compact ticks' do
      let(:run_count) { gc_stat }

      it 'does not run compaction' do
        expect(GC).not_to have_received(:stat)
      end
    end

    context 'when it has been gc_stat ticks' do
      let(:run_count) { gc_stat - 1 }

      it 'runs compaction' do
        expect(GC).to have_received(:stat)
      end

      context 'with a logger', logger: true do
        it 'logs gc compact' do
          expect(@messages).to include(
            contain_exactly(:info, :gc_stat, a_hash_including(stat: {some: :stats}))
          )
        end
      end
    end
  end

  context 'when gc_compact is >= 0' do
    let(:gc_compact) { 60 }

    context 'when it has not been gc_compact ticks' do
      let(:run_count) { gc_compact }

      it 'does not run compaction' do
        expect(GC).not_to have_received(:compact)
      end
    end

    context 'when it has been gc_compact ticks' do
      let(:run_count) { gc_compact - 1 }

      it 'runs compaction' do
        expect(GC).to have_received(:compact)
      end

      context 'with a logger', logger: true do
        it 'logs gc compact' do
          expect(@messages).to include(
            contain_exactly(:info, :gc_compact, a_hash_including(compact: {did: :thing}))
          )
        end
      end
    end
  end
end

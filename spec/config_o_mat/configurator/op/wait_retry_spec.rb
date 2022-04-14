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

require 'config_o_mat/configurator/op/wait_retry'

require 'config_o_mat/configurator/memory'

require 'logsformyfamily'

RSpec.describe ConfigOMat::Op::WaitRetry do
  def perform
    described_class.call(state)
  end

  before do
    @sleep_time = nil
    allow(Kernel).to receive(:sleep) { |arg| @sleep_time = arg.to_i }
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      retry_wait: retry_wait,
      retry_count: retry_count,
      retries_left: retries_left,
      logger: logger
    )
  end

  let(:retry_wait) { 10 }
  let(:retry_count) { 3 }
  let(:retries_left) { 3 }
  let(:logger) { nil }

  it 'decrements retries_left' do
    expect(state.retries_left).to eq retries_left - 1
  end

  it 'sleeps' do
    expect(Kernel).to have_received(:sleep).with(be_within(retry_wait / 2).of(retry_wait))
  end

  context 'when we have already retried' do
    let(:retries_left) { 1 }

    it 'decrements retries_left' do
      expect(state.retries_left).to eq 0
    end

    it 'sleeps longer' do
      expect(Kernel).to have_received(:sleep).with(be_within(retry_wait / 2).of(retry_wait * 4))
    end
  end

  context 'with a logger', logger: true do
    it 'logs the retry' do
      expect(@messages).to include(
        contain_exactly(:notice, :retry_wait, a_hash_including(wait: @sleep_time))
      )
    end
  end
end

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

require 'config_o_mat/configurator/cond/first_run'

require 'config_o_mat/configurator/memory'

RSpec.describe ConfigOMat::Cond::FirstRun do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      run_count: run_count
    )
  end

  context 'when run_count is 0' do
    let(:run_count) { 0 }

    it 'returns true' do
      expect(result).to be true
    end
  end

  context 'when early_exit is greater than 0' do
    let(:run_count) { rand(1_000_000) + 1 }

    it 'returns false' do
      expect(result).to be false
    end
  end
end

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

require 'config_o_mat/shared/cond/early_exit'

require 'config_o_mat/configurator/memory'

RSpec.describe ConfigOMat::Cond::EarlyExit do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      early_exit: early_exit
    )
  end

  context 'when early_exit is true' do
    let(:early_exit) { true }

    it 'returns true' do
      expect(result).to be true
    end
  end

  context 'when early_exit is false' do
    let(:early_exit) { false }

    it 'returns false' do
      expect(result).to be false
    end
  end
end

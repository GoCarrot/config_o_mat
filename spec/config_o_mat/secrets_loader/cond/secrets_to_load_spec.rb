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

require 'config_o_mat/secrets_loader/cond/secrets_to_load'

require 'config_o_mat/secrets_loader/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Cond::SecretsToLoad do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    s = ConfigOMat::SecretsLoader::Memory.new
    s.update_secret_defs_to_load(secrets_to_load)
  end

  context 'with no secrets to load' do
    let(:secrets_to_load) { [] }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with secrets to load' do
    let(:secrets_to_load) { [ConfigOMat::Secret.new(:foo, secret_id: 'foo')] }

    it 'is true' do
      expect(result).to be true
    end
  end
end

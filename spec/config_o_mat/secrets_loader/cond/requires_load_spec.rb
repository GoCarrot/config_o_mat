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

require 'config_o_mat/secrets_loader/cond/requires_load'

require 'config_o_mat/secrets_loader/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Cond::RequiresLoad do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    s = ConfigOMat::SecretsLoader::Memory.new(
      loading_secret: loading_secret
    )
  end

  context 'with no secret to load' do
    let(:loading_secret) { nil }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with a secret to load' do
    let(:loading_secret) { [ConfigOMat::Secret.new(:foo, secret_id: 'foo')] }

    it 'is true' do
      expect(result).to be true
    end
  end
end

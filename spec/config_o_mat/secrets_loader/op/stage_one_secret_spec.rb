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

require 'config_o_mat/secrets_loader/op/stage_one_secret'

require 'config_o_mat/secrets_loader/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::StageOneSecret do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::SecretsLoader::Memory.new(
      secret_defs_to_load: secret_defs_to_load,
    )
  end

  let(:secret_defs_to_load) do
    [
      ConfigOMat::Secret.new(:foo, secret_id: 'foo'),
      ConfigOMat::Secret.new(:bar, secret_id: 'bar')
    ]
  end

  it 'sets a profile from profiles to apply as the profile being applied' do
    expect(state).to have_attributes(
      secret_defs_to_load: secret_defs_to_load[0...1],
      loading_secret: secret_defs_to_load[1]
    )
  end
end

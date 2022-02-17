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

require 'config_o_mat/configurator/op/stage_one_profile'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::StageOneProfile do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profiles_to_apply: profiles_to_apply,
    )
  end

  let(:profiles_to_apply) do
    [
      ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        nil
      ),
      ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source1, '3', { answer: 181 }.to_json, 'application/json'),
        nil
      )
    ]
  end

  it 'sets a profile from profiles to apply as the profile being applied' do
    expect(state).to have_attributes(
      profiles_to_apply: profiles_to_apply[0...1],
      applying_profile: profiles_to_apply[1]
    )
  end

  context 'with an invalid profile' do
    let(:profiles_to_apply) do
      [
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source1, '3', '{"answer: 181', 'application/json'),
          nil
        )
      ]
    end

    it 'sets a profile from profiles to apply as the profile being applied' do
      expect(state).to have_attributes(
        profiles_to_apply: [],
        applying_profile: profiles_to_apply[0]
      )
    end
  end
end

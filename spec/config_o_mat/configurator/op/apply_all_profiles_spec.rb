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

require 'config_o_mat/configurator/op/apply_all_profiles'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::ApplyAllProfiles do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profiles_to_apply: profiles_to_apply,
      applied_profiles: applied_profiles
    )
  end

  let(:profiles_to_apply) do
    [
      ConfigOMat::LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
      ConfigOMat::LoadedProfile.new(:source1, '3', { answer: 181 }.to_json, 'application/json')
    ]
  end

  let(:applied_profiles) { {} }

  it 'applies all profiles to apply' do
    expect(state).to have_attributes(
      profiles_to_apply: [],
      applied_profiles: Hash[profiles_to_apply.map { |prof| [prof.name, prof] }]
    )
  end

  context 'with profiles already applied' do
    let(:applied_profiles) do
      {
        source1: ConfigOMat::LoadedProfile.new(:source1, '2', { answer: 5 }.to_json, 'application/json'),
        source2: ConfigOMat::LoadedProfile.new(:source2, '8', { answer: 255 }.to_json, 'application/json')
      }
    end

    it 'applies all profiles to apply and keeps exisiting profiles' do
      expect(state).to have_attributes(
        profiles_to_apply: [],
        applied_profiles: {
          source0: profiles_to_apply[0],
          source1: profiles_to_apply[1],
          source2: applied_profiles[:source2]
        }
      )
    end
  end

  context 'with an errored profile' do
    let(:profiles_to_apply) do
      [
        ConfigOMat::LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        ConfigOMat::LoadedProfile.new(:source1, '3', '{ "answer": 181 ', 'application/json')
      ]
    end

    it 'errors' do
      expect(result.errors).to match(
        source1: [{ contents: [an_instance_of(JSON::ParserError)] }]
      )
    end
  end
end

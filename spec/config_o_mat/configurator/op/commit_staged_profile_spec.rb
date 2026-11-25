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

require 'config_o_mat/configurator/op/commit_staged_profile'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::CommitStagedProfile do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      applied_profiles: applied_profiles,
      applying_profile: applying_profile,
      rejected_profiles: rejected_profiles,
      profiles_to_apply: profiles_to_apply
    )
  end

  let(:source0) do
    ConfigOMat::LoadedProfile.new(
      ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
      nil
    )
  end

  let(:source1) do
    ConfigOMat::LoadedProfile.new(
      ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 5 }.to_json, 'application/json'),
      nil
    )
  end

  let(:n_source1) do
    ConfigOMat::LoadedProfile.new(
      ConfigOMat::LoadedAppconfigProfile.new(:source1, '3', { answer: 181 }.to_json, 'application/json'),
      nil
    )
  end

  let(:applying_profile) { n_source1 }
  let(:rejected_profiles) { {} }
  let(:profiles_to_apply) { [] }
  let(:applied_profiles) do
    {
      source0: source0,
      source1: source1
    }
  end

  it 'applies the current applying profile' do
    expect(state).to have_attributes(
      applied_profiles: applied_profiles.yield_self { |ap| ap.dup.merge(applying_profile.name => applying_profile) },
      applying_profile: nil,
    )
  end

  context 'when no profile is being applied' do
    let(:applying_profile) { nil }

    it 'does not error' do
      expect(result.errors?).to be false
    end

    it 'does not update state' do
      expect(state).to have_attributes(
        applied_profiles: applied_profiles,
        applying_profile: nil
      )
    end
  end
  context 'when the committed profile was rejected at an older version' do
    let(:rejected_profiles) { { source1: source1 } }

    it 'clears the rejection' do
      expect(state.rejected_profiles).to be_empty
      expect(state.profiles_to_apply).to be_empty
    end
  end

  context 'when another profile is rejected' do
    let(:r_source0) do
      ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source0, '2', { other: 1 }.to_json, 'application/json'),
        nil
      )
    end
    let(:rejected_profiles) { { source0: r_source0 } }

    it 'queues it to be tried again, keeping the rejection until it commits' do
      expect(state.profiles_to_apply).to eq [r_source0]
      expect(state.rejected_profiles).to eq(source0: r_source0)
    end

    context 'when a newer version of it is already queued' do
      let(:profiles_to_apply) { [source0] }

      it 'does not queue the rejected one' do
        expect(state.profiles_to_apply).to eq [source0]
      end
    end
  end
end

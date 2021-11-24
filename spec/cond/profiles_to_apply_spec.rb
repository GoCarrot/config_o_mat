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

require 'cond/profiles_to_apply'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Cond::ProfilesToApply do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      profiles_to_apply: profiles_to_apply
    )
  end

  context 'with no profiles to apply' do
    let(:profiles_to_apply) { [] }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with profiles to apply' do
    let(:profiles_to_apply) { [LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json')] }

    it 'is true' do
      expect(result).to be true
    end
  end
end

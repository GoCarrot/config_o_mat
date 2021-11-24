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

require 'cond/services_to_reload'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Cond::ServicesToReload do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      services_to_reload: services_to_reload
    )
  end

  context 'with no services to reload' do
    let(:services_to_reload) { [] }

    it 'is false' do
      expect(result).to be false
    end
  end

  context 'with services to reload' do
    let(:services_to_reload) { [:service0, :service1] }

    it 'is true' do
      expect(result).to be true
    end
  end
end

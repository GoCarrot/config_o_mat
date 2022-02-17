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

require 'config_o_mat/flip_flopper/cond/service_status'

require 'config_o_mat/flip_flopper/memory'

RSpec.describe ConfigOMat::Cond::ServiceStatus do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::FlipFlopper::Memory.new(
      activation_status: activation_status
    )
  end

  let(:activation_status) { %i[starting started failed timed_out].sample }

  it 'returns the service status' do
    expect(result).to eq activation_status
  end
end

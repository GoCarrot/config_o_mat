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

require 'config_o_mat/flip_flopper/op/report_failure'

require 'config_o_mat/flip_flopper/memory'

RSpec.describe ConfigOMat::Op::ReportFailure do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::FlipFlopper::Memory.new(
      activation_status: activation_status,
    )
  end

  context 'when activation_status is failed' do
    let(:activation_status) { :failed }

    it 'reports failure' do
      expect(result.errors).to match(
        service: ['failed to start service instance']
      )
    end
  end

  context 'when activation_status is timed_out' do
    let(:activation_status) { :timed_out }

    it 'reports failure' do
      expect(result.errors).to match(
        service: ['service instance did not start within timeout']
      )
    end
  end

  context 'when activation_status is something else' do
    let(:activation_status) { :uhhh_what }

    it 'reports failure' do
      expect(result.errors).to match(
        service: ['service instance failed due to an unknown error (uhhh_what)']
      )
    end
  end
end

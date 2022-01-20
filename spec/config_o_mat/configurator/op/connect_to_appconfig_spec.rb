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

require 'config_o_mat/configurator/op/connect_to_appconfig'

require 'config_o_mat/configurator/memory'

require 'logsformyfamily'

RSpec.describe ConfigOMat::Op::ConnectToAppconfig do
  def perform
    described_class.call(state)
  end

  before do
    allow(Aws::AppConfig::Client).to receive(:new).and_return(client_stub)
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      region: region,
      logger: logger
    )
  end

  let(:client_stub) do
    Aws::AppConfig::Client.new(stub_responses: true)
  end

  let(:region) { nil }
  let(:logger) { nil }

  it 'uses the default region' do
    expect(Aws::AppConfig::Client).to have_received(:new).with(hash_excluding(:region))
  end

  context 'with a region' do
    let(:region) { 'us-west-2' }

    it 'uses the configured region' do
      expect(Aws::AppConfig::Client).to have_received(:new).with(a_hash_including(region: region))
    end
  end

  context 'with a logger' do
    let(:logger) { LogsForMyFamily::Logger.new }

    it 'passes the logger to the client' do
      expect(Aws::AppConfig::Client).to have_received(:new).with(a_hash_including(logger: logger))
    end
  end
end

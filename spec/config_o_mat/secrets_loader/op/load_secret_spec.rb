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

require 'config_o_mat/secrets_loader/op/load_secret'

require 'config_o_mat/secrets_loader/memory'
require 'config_o_mat/shared/types'

require 'aws-sdk-secretsmanager'
require 'logsformyfamily'

RSpec.describe ConfigOMat::Op::LoadSecret do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::SecretsLoader::Memory.new(
      loading_secret: loading_secret,
      secretsmanager_client: client_stub,
      logger: logger
    )
  end

  let(:stub_responses) do
    {
      'test' => {
        secret_string: secret_string, version_id: '96444d8e-b27a-4b15-be2a-dc217b936bee',
        arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124', name: 'test-123',
        version_stages: nil
      }
    }
  end

  let(:secret_string) { { answer: 42 }.to_json }
  let(:loaded_secret) { ConfigOMat::LoadedSecret.new(:foo, 'test', '96444d8e-b27a-4b15-be2a-dc217b936bee', secret_string, 'application/json') }

  let(:client_stub) do
    Aws::SecretsManager::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_secret_value, proc do |request|
        stub_responses[request.params[:secret_id]]
      end)
    end
  end

  let(:logger) { nil }
  let(:version_id) { nil }
  let(:version_stage) { nil }

  let(:loading_secret) do
    ConfigOMat::Secret.new(:foo, secret_id: 'test', version_id: version_id, version_stage: version_stage)
  end

  shared_examples_for 'retrieved secret' do
    it 'caches the returned secret' do
      expect(state.secrets_cache).to match(hash_including(
        'test' => loaded_secret
      ))
    end

    it 'adds the loaded secret to our output' do
      expect(state.loaded_secrets).to match(hash_including(
        loading_secret => loaded_secret
      ))
    end

    it 'sets loading_secret to nil' do
      expect(state.loading_secret).to be nil
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs' do
        expect(@messages).to include(
          contain_exactly(
            :info, :loaded_secret, a_hash_including(
              name: :foo,
              version_id: '96444d8e-b27a-4b15-be2a-dc217b936bee',
              arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124'
            )
          )
        )
      end
    end
  end

  context 'with no version_id or version_stage' do
    it 'makes a request for AWSCURRENT' do

    end

    include_examples 'retrieved secret'
  end

  context 'with a version_id' do
    let(:version_id) { '96444d8e-b27a-4b15-be2a-dc217b936bee' }

    it 'makes a request for the version id' do
      expect(client_stub.api_requests[0][:params]).to eq(secret_id: 'test', version_id: version_id)
    end

    include_examples 'retrieved secret'
  end

  context 'when the secret does not parse' do
    let(:secret_string) { { answer: 42 }.to_json[0..-2] }

    it 'errors' do
      expect(result.errors).to match(
        foo: [an_instance_of(ConfigOMat::ConfigItem::ValidationError).and(have_attributes(
          errors: { contents: [an_instance_of(JSON::ParserError)] }
        ))]
      )
    end

    it 'does not update the cache' do
      expect(state.secrets_cache).to eq({})
    end

    it 'does not updated loaded_secrets' do
      expect(state.loaded_secrets).to eq({})
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs' do
        expect(@messages).to include(
          contain_exactly(
            :error, :invalid_secret, a_hash_including(
              name: :foo,
              version_id: '96444d8e-b27a-4b15-be2a-dc217b936bee',
              arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124',
              errors: an_instance_of(ConfigOMat::ConfigItem::ValidationError).and(have_attributes(
                errors: { contents: [an_instance_of(JSON::ParserError)] }
              ))
            )
          )
        )
      end
    end
  end

  context 'when the load fails' do
    let(:stub_responses) do
      {
        'test' => 'ResourceNotFoundException',
      }
    end

    it 'errors' do
      expect(result.errors).to  match(
        foo: [an_instance_of(Aws::SecretsManager::Errors::ResourceNotFoundException)]
      )
    end

    it 'does not update the cache' do
      expect(state.secrets_cache).to eq({})
    end

    it 'does not updated loaded_secrets' do
      expect(state.loaded_secrets).to eq({})
    end
  end
end

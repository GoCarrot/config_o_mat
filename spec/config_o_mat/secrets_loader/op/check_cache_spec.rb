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

require 'config_o_mat/secrets_loader/op/check_cache'

require 'config_o_mat/secrets_loader/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::CheckCache do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::SecretsLoader::Memory.new(
      loading_secret: loading_secret,
      secrets_cache: secrets_cache,
      logger: logger
    )
  end

  let(:version_id) { '96444d8e-b27a-4b15-be2a-dc217b936bee' }

  let(:loaded_secret) do
    ConfigOMat::LoadedSecret.new(
      :foo, 'foo', version_id, {answer: 42}.to_json, 'application/json'
    )
  end

  let(:secrets_cache) do
    {
      'foo' => loaded_secret
    }
  end

  let(:logger) { nil }

  context 'when the secret uses a version stage' do
    let(:loading_secret) { ConfigOMat::Secret.new(:foo, secret_id: 'foo') }

    it 'does not load from cache' do
      expect(state).to have_attributes(
        loading_secret: loading_secret,
        loaded_secrets: {}
      )
    end
  end

  context 'when the secret is not cached' do
    let(:loading_secret) { ConfigOMat::Secret.new(:foo, secret_id: 'bar', version_id: version_id) }

    it 'does not load from cache' do
      expect(state).to have_attributes(
        loading_secret: loading_secret,
        loaded_secrets: {}
      )
    end
  end

  context 'when a different version of the secret is cached' do
    let(:loading_secret) { ConfigOMat::Secret.new(:foo, secret_id: 'foo', version_id: version_id.succ) }

    it 'does not load from cache' do
      expect(state).to have_attributes(
        loading_secret: loading_secret,
        loaded_secrets: {}
      )
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
            :info, :invalid_cached_secret, a_hash_including(
              name: :foo, expected_version_id: loading_secret.version_id,
              cached_version_id: version_id
            )
          )
        )
      end
    end
  end

  context 'when the requested version of the secret is cached' do
    let(:loading_secret) { ConfigOMat::Secret.new(:foo, secret_id: 'foo', version_id: version_id) }

    it 'loads from cache' do
      expect(state).to have_attributes(
        loading_secret: nil,
        loaded_secrets: {
          loading_secret => loaded_secret
        }
      )
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
            :info, :cached_secret, a_hash_including(name: :foo, version_id: version_id)
          )
        )
      end
    end
  end
end

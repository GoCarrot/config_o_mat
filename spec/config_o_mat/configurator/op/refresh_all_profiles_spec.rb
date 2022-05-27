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

require 'config_o_mat/configurator/op/refresh_all_profiles'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

require 'aws-sdk-appconfig'
require 'aws-sdk-s3'
require 'aws-sdk-secretsmanager'
require 'logsformyfamily'

require 'securerandom'

RSpec.describe ConfigOMat::Op::RefreshAllProfiles do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profile_defs: profile_defs,
      applied_profiles: applied_profiles,
      client_id: client_id,
      appconfig_client: client_stub,
      secretsmanager_client: sm_client_stub,
      s3_client: s3_client_stub,
      logger: logger
    )
  end

  let(:profile_defs) do
    {
      source0: ConfigOMat::Profile.new(application: 'test', environment: 'test', profile: 'test'),
      source1: ConfigOMat::Profile.new(
        application: 'foo', environment: 'bar', profile: 'boo',
        s3_fallback: { bucket: 'zebucket', object: 'foo_fallback' }
      ),
      source2: ConfigOMat::Profile.new(application: 'other', environment: 'test', profile: 'test'),
      source3: ConfigOMat::FacterProfile.new
    }
  end

  let(:applied_profiles) do
    {
      source0: ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        nil
      ),
      source1: ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source1, '1', { answer: 255 }.to_json, 'application/json'),
        nil
      ),
      source3: ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedFacterProfile.new(:source3),
        nil
      )
    }
  end

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '1', content_type: 'application/json' },
      'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
      'other' => { content: StringIO.new({ answer: 255 }.to_json), configuration_version: '1', content_type: 'application/json' }
    }
  end

  let(:client_stub) do
    Aws::AppConfig::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_configuration, proc do |request|
        stub_responses[request.params[:application]]
      end
      )
    end
  end

  let(:secretsmanager_stubs) { {} }
  let(:s3_stubs) { {} }

  let(:sm_client_stub) do
    Aws::SecretsManager::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_secret_value, proc do |request|
        secretsmanager_stubs[request.params[:secret_id]]
      end)
    end
  end

  let(:s3_client_stub) do
    Aws::S3::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_object, proc do |request|
        s3_stubs[request.params[:key]]
      end)
    end
  end

  let(:client_id) { SecureRandom.uuid }
  let(:logger) { nil }

  context 'when all profiles refresh' do
    it 'includes versions for applied profiles' do
      expect(client_stub.api_requests).to contain_exactly(
        a_hash_including(
          params: { application: 'test', environment: 'test', configuration: 'test', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'foo', environment: 'bar', configuration: 'boo', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'other', environment: 'test', configuration: 'test', client_id: client_id }
        )
      )
    end

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
          nil
        ),
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json'),
          nil
        )
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end

    context 'with secrets' do
      let(:with_secrets_content) do
        {
          answer: 181,
          "aws:secrets" => {
            my_secret: {
              secret_id: 'TestSecretThing',
              version_id: '3b452578-53ed-42d7-8d72-eeb01bf5545c'
            },
            other_secret: {
              secret_id: 'OtherSecret'
            }
          }
        }.to_json
      end

      let(:stub_responses) do
        {
          'test' => {
            content: StringIO.new({ answer: 42, }.to_json), configuration_version: '1', content_type: 'application/json'
          },
          'foo' => {
            content: StringIO.new(with_secrets_content), configuration_version: '2', content_type: 'application/json'
          },
          'other' => { content: StringIO.new({ answer: 255 }.to_json), configuration_version: '1', content_type: 'application/json' }
        }
      end

      let(:secretsmanager_stubs) do
        {
          'TestSecretThing' => {
            secret_string: { answer: 91 }.to_json, version_id: '3b452578-53ed-42d7-8d72-eeb01bf5545c',
            arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124', name: 'test-123',
            version_stages: nil
          },
          'OtherSecret' => {
            secret_string: { answer: 191 }.to_json, version_id: '3b452578-53ed-42d7-8d72-eeb01bf5545c',
            arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124', name: 'test-123',
            version_stages: ['AWSCURRENT']
          }
        }
      end

      it 'sets the profiles to apply' do
        expect(state.profiles_to_apply).to contain_exactly(
          ConfigOMat::LoadedProfile.new(
            ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', with_secrets_content, 'application/json'),
            {
              my_secret: ConfigOMat::LoadedSecret.new(
                :my_secret, 'TestSecretThing', '3b452578-53ed-42d7-8d72-eeb01bf5545c', { answer: 91 }.to_json, 'application/json'
              ),
              other_secret: ConfigOMat::LoadedSecret.new(
                :other_secret, 'OtherSecret', '3b452578-53ed-42d7-8d72-eeb01bf5545c', { answer: 191 }.to_json, 'application/json'
              )
            }
          ),
          ConfigOMat::LoadedProfile.new(
            ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json'),
            nil
          )
        )
      end

      context 'when the secrets load errors' do
        let(:secretsmanager_stubs) do
          {
            'TestSecretThing' => {
              secret_string: { answer: 91 }.to_json, version_id: '3b452578-53ed-42d7-8d72-eeb01bf5545c',
              arn: 'arn:aws:secretsmanager:us-east-1:1234:secret:test-124', name: 'test-123',
              version_stages: nil
            },
            'OtherSecret' => 'ResourceNotFoundException'
          }
        end

        it 'errors' do
          expect(result.errors).to match(
            source1_secrets: [{other_secret: [an_instance_of(Aws::SecretsManager::Errors::ResourceNotFoundException)]}]
          )
        end
      end
    end

    context 'with a logger', logger: true do
      RSpec::Matchers.define_negated_matcher :an_array_excluding, :include

      it 'logs updated profiles' do
        expect(@messages).to include(
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source1, previous_version: '1', new_version: '2')
          ),
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source2, previous_version: nil, new_version: '1')
          )
        ).and(an_array_excluding(include(a_hash_including(name: :source0))))
      end
    end
  end

  context 'with no applied profiles' do
    let(:applied_profiles) { nil }

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
          nil
        ),
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
          nil
        ),
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json'),
          nil
        ),
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedFacterProfile.new(:source3),
          nil
        )
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end
  end

  context 'when a profile update errors' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
        'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
        'other' => 'BadRequestException'
      }
    end

    it 'errors' do
      expect(result.errors).to match(
        source2: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end

  context 'when a profile with an s3 fallback errors' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
        'foo' => 'BadRequestException',
        'other' => { content: StringIO.new({ answer: 255 }.to_json), configuration_version: '1', content_type: 'application/json' }
      }
    end

    let(:s3_version_id) { SecureRandom.hex }

    let(:s3_stubs) do
      {
        'foo_fallback' => {
          body: StringIO.new({ answer: 512 }.to_json),
          version_id: s3_version_id,
          content_type: 'application/json'
        }
      }
    end

    it 'uses the s3 fallback data' do
      expect(state.profiles_to_apply).to contain_exactly(
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source1, s3_version_id, { answer: 512 }.to_json, 'application/json', true),
          nil
        ),
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json'),
          nil
        )
      )
    end

    context 'with a logger', logger: true do
      it 'logs an error indicating fallback was used' do
        expect(@messages).to include(
          contain_exactly(:error, :s3_fallback_request, a_hash_including(name: :source1, reason: an_instance_of(Aws::AppConfig::Errors::BadRequestException)))
        )
      end
    end

    context 'when the s3 fallback errors' do
      let(:s3_stubs) do
        {
          'foo_fallback' => 'BadRequestException'
        }
      end

      it 'errors' do
        expect(result.errors).to match(
          source1: [an_instance_of(Aws::S3::Errors::BadRequestException)]
        )
      end
    end
  end
end

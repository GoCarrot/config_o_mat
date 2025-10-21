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

require 'config_o_mat/configurator/op/refresh_profile'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'
require 'config_o_mat/secrets_loader'

require 'aws-sdk-appconfig'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-s3'
require 'logsformyfamily'

RSpec.describe ConfigOMat::Op::RefreshProfile do
  def perform
    described_class.call(state)
  end

  subject(:result) { perform }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profile_defs: profile_defs,
      client_id: client_id,
      applying_profile: applying_profile,
      appconfig_client: client_stub,
      secretsmanager_client: sm_client_stub,
      s3_client: s3_client_stub,
      logger: logger,
      fallback_s3_bucket: 'zebucket'
    )
  end

  let(:profile_defs) do
    {
      source0: ConfigOMat::Profile.new(application: 'test', environment: 'test', profile: 'test')
    }
  end

  let(:applying_profile) do
    ConfigOMat::LoadedProfile.new(
      ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', '{"answer": 42', 'application/json'),
      nil
    )
  end

  let(:client_id) { SecureRandom.uuid }

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '2', content_type: 'application/json' },
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

  let(:sm_client_stub) do
    Aws::SecretsManager::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_secret_value, proc do |request|
        secretsmanager_stubs[request.params[:secret_id]]
      end)
    end
  end

  let(:s3_stubs) { {} }

  let(:s3_client_stub) do
    Aws::S3::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_object, proc do |request|
        s3_stubs[request.params[:key]]
      end)
    end
  end

  let(:logger) { nil }

  context 'when the profile is updated' do
    it 'updates applying_profile' do
      subject
      expect(state.applying_profile).to eq(
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source0, '2', { answer: 42 }.to_json, 'application/json'),
          nil
        )
      )
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
            content: StringIO.new(with_secrets_content), configuration_version: '2', content_type: 'application/json'
          },
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

      it 'updates applying_profile' do
        subject
        expect(state.applying_profile).to eq(
          ConfigOMat::LoadedProfile.new(
            ConfigOMat::LoadedAppconfigProfile.new(:source0, '2', with_secrets_content, 'application/json'),
            {
              my_secret: ConfigOMat::LoadedSecret.new(
                :my_secret, 'TestSecretThing', '3b452578-53ed-42d7-8d72-eeb01bf5545c', { answer: 91 }.to_json, 'application/json'
              ),
              other_secret: ConfigOMat::LoadedSecret.new(
                :other_secret, 'OtherSecret', '3b452578-53ed-42d7-8d72-eeb01bf5545c', { answer: 191 }.to_json, 'application/json'
              )
            }
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
            source0_secrets: [{other_secret: [an_instance_of(Aws::SecretsManager::Errors::ResourceNotFoundException)]}]
          )
        end
      end
    end

    context 'with a logger', logger: true do
      it 'logs the update' do
        subject
        expect(@messages).to include(
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source0, previous_version: '1', new_version: '2')
          )
        )
      end
    end
  end

  context 'when the profile is not updated' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
      }
    end

    it 'does not update applying_profile' do
      subject
      expect(state.applying_profile).to eq applying_profile
    end

    it 'does not error' do
      subject
      expect(result.errors?).to be false
    end

    context 'with a logger', logger: true do
      it 'logs a warning' do
        subject
        expect(@messages).to include(
          contain_exactly(
            :warning, :no_update, a_hash_including(name: :source0, version: '1')
          )
        )
      end
    end
  end

  context 'when the update fails' do
    let(:stub_responses) do
      {
        'test' => 'BadRequestException',
      }
    end

    it 'errors' do
      subject
      expect(result.errors).to  match(
        source0: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end

  context 'when a profile with an s3 fallback errors' do
    let(:profile_defs) do
      {
        source0: ConfigOMat::Profile.new(
          application: 'test', environment: 'test', profile: 'test',
          s3_fallback: 'test_fallback'
        )
      }
    end

    let(:stub_responses) do
      {
        'test' => 'BadRequestException',
      }
    end

    let(:s3_version_id) { SecureRandom.hex }

    let(:s3_stubs) do
      {
        'test_fallback' => {
          body: StringIO.new({ answer: 512 }.to_json),
          version_id: s3_version_id,
          content_type: 'application/json'
        }
      }
    end

    it 'uses the s3 fallback data' do
      subject
      expect(state.applying_profile).to eq(
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source0, s3_version_id, { answer: 512 }.to_json, 'application/json', true),
          nil
        )
      )
    end

    context 'with a logger', logger: true do
      it 'logs an error indicating fallback was used' do
        subject
        expect(@messages).to include(
          contain_exactly(:error, :s3_fallback_request, a_hash_including(name: :source0, reason: an_instance_of(Aws::AppConfig::Errors::BadRequestException)))
        )
      end
    end

    context 'when the s3 fallback errors' do
      let(:s3_stubs) do
        {
          'test_fallback' => 'BadRequestException'
        }
      end

      it 'errors' do
        expect(result.errors).to match(
          source0: [an_instance_of(Aws::S3::Errors::BadRequestException)]
        )
      end
    end
  end

  context 'with a facter profile' do
    let(:profile_defs) do
      {
        source0: ConfigOMat::FacterProfile.new
      }
    end

    let(:applying_profile) do
      ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedFacterProfile.new(:source0),
        nil
      )
    end

    context 'when the profile is not updated' do
      it 'does not update applying_profile' do
        subject
        expect(state.applying_profile).to eq applying_profile
      end

      it 'does not error' do
        subject
        expect(result.errors?).to be false
      end

      context 'with a logger', logger: true do
        it 'logs a warning' do
          subject
          expect(@messages).to include(
            contain_exactly(
              :warning, :no_update, a_hash_including(name: :source0, version: applying_profile.version)
            )
          )
        end
      end
    end

    context 'when the profile is updated' do
      let(:fake_profile) do
        instance_double(
          ConfigOMat::LoadedFacterProfile,
          name: :source0,
          version: 42,
          contents: {is: 'new'},
          errors?: false
        )
      end

      before do
        # Generate the facter profile before we stub out the constructor.
        applying_profile
        allow(ConfigOMat::LoadedFacterProfile).to receive(:new).and_return(fake_profile)
      end

      it 'updates applying_profile' do
        subject
        expect(state.applying_profile).to eq(
          ConfigOMat::LoadedProfile.new(
            fake_profile,
            nil
          )
        )
      end

      context 'with a logger', logger: true do
        it 'logs the update' do
          subject
          expect(@messages).to include(
            contain_exactly(
              :notice, :updated_profile, a_hash_including(name: :source0, previous_version: applying_profile.version, new_version: 42)
            )
          )
        end
      end
    end
  end
end

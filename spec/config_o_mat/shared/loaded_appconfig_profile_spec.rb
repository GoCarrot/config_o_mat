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

require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::LoadedAppconfigProfile do
  subject(:profile) do
    described_class.new(name, version, contents, content_type)
  end

  let(:name) { :source0 }
  let(:version) { '1' }
  let(:contents) { { answer: 42 }.to_json }
  let(:content_type) { 'application/json' }

  context 'with json' do
    it 'parses the json' do
      expect(profile).to have_attributes(
        name: name, version: version,
        contents: { answer: 42 },
        errors?: false
      )
    end

    context 'with aws:secrets' do
      let(:contents) do
        {
          answer: 42,
          :"aws:secrets" => {
            test: {
              secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-124',
              version_id: '95aa0202-8b17-4e32-b078-3cd5bdc6e567'
            },
            other_test: {
              secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-129',
            },
            previous_test: {
              secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-145',
              version_stage: 'AWSPREVIOUS'
            },
            plain_test: {
              secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-154',
              content_type: 'text/plain'
            }
          }
        }.to_json
      end

      it 'provides secrets' do
        expect(profile).to have_attributes(
          name: name, version: version,
          contents: JSON.parse(contents, symbolize_names: true),
          errors?: false,
          secret_defs: a_hash_including(
            test: eq(
              ConfigOMat::Secret.new(
                secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-124',
                version_id: '95aa0202-8b17-4e32-b078-3cd5bdc6e567',
                version_stage: nil,
                content_type: 'application/json'
              )
            ),
            other_test: eq(
              ConfigOMat::Secret.new(
                secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-129',
                version_id: nil,
                version_stage: 'AWSCURRENT',
                content_type: 'application/json'
              )
            ),
            previous_test: eq(
              ConfigOMat::Secret.new(
                secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-145',
                version_id: nil,
                version_stage: 'AWSPREVIOUS',
                content_type: 'application/json'
              )
            ),
            plain_test: eq(
              ConfigOMat::Secret.new(
                secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-154',
                version_id: nil,
                version_stage: 'AWSCURRENT',
                content_type: 'text/plain'
              )
            )
          )
        )
      end
    end

    context 'with invalid secrets' do
      let(:contents) do
        {
          answer: 42,
          :"aws:secrets" => {
            test: {
              version_id: '95aa0202-8b17-4e32-b078-3cd5bdc6e567'
            },
            other_test: {
              secret_id: 'arn:aws:secretsmanager:us-east-1:12345:secret:test-129',
              content_type: 'application/wtf'
            },
          }
        }.to_json
      end

      it 'errors' do
        expect(profile).to have_attributes(
          errors?: true,
          errors: a_hash_including(
            contents_secrets_test: [a_hash_including(
              secret_id: ['must be present']
            )],
            contents_secrets_other_test: [a_hash_including(
              content_type: [include('must be one of')]
            )]
          )
        )
      end
    end

    context 'with an invalid secrets type' do
      let(:contents) do
        {
          answer: 42,
          :"aws:secrets" => []
        }.to_json
      end

      it 'errors' do
        expect(profile).to have_attributes(
          errors?: true,
          errors: a_hash_including(
            contents_secrets: ['must be a dictionary']
          )
        )
      end
    end
  end

  context 'with invalid json' do
    let(:contents) { '{ "answer": 42 ' }

    it 'reports errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { contents: [an_instance_of(JSON::ParserError)] }
      )
    end
  end

  context 'with yaml' do
    let(:contents) { "answer: 42\n" }
    let(:content_type) { 'application/x-yaml' }

    it 'parses the yaml' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: { answer: 42 },
        errors?: false
      )
    end
  end

  context 'with invalid yaml' do
    let(:contents) { "foo:\n  - bar\n  -jkfd\n  - baz\n" }
    let(:content_type) { 'application/x-yaml' }

    it 'reports errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { contents: [an_instance_of(Psych::SyntaxError)] }
      )
    end
  end

  context 'with plain text' do
    let(:contents) { 'foobarbaz' }
    let(:content_type) { 'text/plain' }

    it 'uses the text as content' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: contents, errors?: false
      )
    end
  end

  context 'with an invalid content_type' do
    let(:content_type) { 'application/x-dne' }

    it 'errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { content_type: [include('must be one of')] }
      )
    end
  end

  describe '#validate' do
    before { profile.validate }

    context 'with an empty name' do
      let(:name) { :"" }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { name: ['must be present'] }
        )
      end
    end

    context 'with an invalid name type' do
      let(:name) { 'foo' }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { name: ['must be a Symbol'] }
        )
      end
    end

    context 'with an empty version' do
      let(:version) { nil }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { version: ['must be present'] }
        )
      end
    end

    context 'with empty contents' do
      let(:content_type) { 'text/plain' }
      let(:contents) { '' }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { contents: ['must be present'] }
        )
      end
    end
  end
end

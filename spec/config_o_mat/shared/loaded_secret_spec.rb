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

RSpec.describe ConfigOMat::LoadedSecret do
  subject(:secret) do
    described_class.new(name, secret_id, version_id, contents, content_type)
  end

  let(:name) { :source0 }
  let(:secret_id) { 'secret' }
  let(:version_id) { '1' }
  let(:content_hash) { { answer: 42 } }
  let(:contents) { content_hash.to_json }
  let(:content_type) { 'application/json' }

  shared_examples_for 'invalid key' do
    context 'when accessing an invalid key' do
      it 'raises an error' do
        expect { secret.contents[:dne] }.to raise_error(
          an_instance_of(KeyError).and having_attributes(
            key: :dne,
            message: "No key :dne in secret #{name}"
          )
        )
      end
    end
  end

  include_examples 'invalid key'
end

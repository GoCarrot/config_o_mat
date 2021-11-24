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

require 'op/parse_meta_cli'

require 'meta_configurator_memory'

RSpec.describe Op::ParseMetaCli do
  def perform
    described_class.call(state)
  end

  before do
    @original_stdout = $stdout
    $stdout = File.open(File::NULL, 'w')
    @result = perform
  end

  after { $stdout = @original_stdout }

  subject(:result) { @result }

  let(:state) { MetaConfiguratorMemory.new(argv: argv, env: env) }
  let(:env) do
    {
      'CONFIGURATION_DIRECTORY' => '/etc/configurator',
      'RUNTIME_DIRECTORY' => '/run/configurator',
      'LOGS_DIRECTORY' => '/var/log/configurator'
    }
  end

  let(:argv) { [] }

  context 'when requesting version' do
    let(:argv) { %w[-v] }

    it 'sets early exit' do
      expect(state.early_exit).to be true
    end

    context 'without directories' do
      let(:env) { {} }

      it 'does not error' do
        expect(result.errors?).to be false
      end
    end
  end

  context 'when requesting help' do
    let(:argv) { %w[-h] }

    it 'sets early exit' do
      expect(state.early_exit).to be true
    end

    it 'outputs help' do
      expect { perform }.to output.to_stdout
    end

    context 'without directories' do
      let(:env) { {} }

      it 'does not error' do
        expect(result.errors?).to be false
      end
    end
  end

  context 'when CONFIGURATION_DIRECTORY is set in env' do
    it 'sets the configuration_directory to the env value' do
      expect(state.configuration_directory).to eq '/etc/configurator'
    end

    context 'when configuration directory is set on the command line' do
      let(:argv) { %w[-c /somewhere/else] }

      it 'prefers the cli value' do
        expect(state.configuration_directory).to eq '/somewhere/else'
      end
    end
  end

  context 'when RUNTIME_DIRECTORY is set in env' do
    it 'sets the runtime_directory to the env value' do
      expect(state.runtime_directory).to eq '/run/configurator'
    end

    context 'when runtime directory is set on the command line' do
      let(:argv) { %w[-r /somewhere/else] }

      it 'prefers the cli value' do
        expect(state.runtime_directory).to eq '/somewhere/else'
      end
    end
  end

  context 'when LOGS_DIRECTORY is set in env' do
    it 'sets the logs_directory to the env value' do
      expect(state.logs_directory).to eq '/var/log/configurator'
    end

    context 'when logs directory is set on the command line' do
      let(:argv) { %w[-l /somewhere/else] }

      it 'prefers the cli value' do
        expect(state.logs_directory).to eq '/somewhere/else'
      end
    end
  end

  context 'when no configuration directory is set' do
    let(:env) { {} }

    it 'errors' do
      expect(result.errors?).to be true
    end

    it 'indicates that the configuration directory is required' do
      expect(result.errors).to have_key :configuration_directory
    end
  end

  context 'when no runtime directory is set' do
    let(:env) do
      {
        'CONFIGURATION_DIRECTORY' => '/etc/configurator'
      }
    end

    it 'errors' do
      expect(result.errors?).to be true
    end

    it 'indicates that the runtime directory is required' do
      expect(result.errors).to have_key :runtime_directory
    end
  end

  context 'when systemd directory is set on the command line' do
    let(:argv) { %w[-s /somewhere/else] }

    it 'sets the systemd_directory to the cli value' do
      expect(state.systemd_directory).to eq '/somewhere/else'
    end
  end

  context 'with the default systemd directory' do
    it 'sets the default systemd directory' do
      expect(state.systemd_directory).to eq described_class::DEFAULT_SYSTEMD_DIRECTORY
    end
  end
end

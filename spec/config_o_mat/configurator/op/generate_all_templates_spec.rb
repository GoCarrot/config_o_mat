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

require 'config_o_mat/configurator/op/generate_all_templates'
require 'config_o_mat/configurator/op/compile_templates'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

require 'logsformyfamily'

require 'tmpdir'

RSpec.describe ConfigOMat::Op::GenerateAllTemplates do
  def perform
    described_class.call(state)
  end

  before do
    @runtime_directory = Dir.mktmpdir
    @result = perform
  end

  after do
    FileUtils.remove_entry @runtime_directory
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      template_defs: template_defs, dependencies: dependencies, applied_profiles: applied_profiles,
      applying_profile: applying_profile, generated_templates: generated_templates,
      compiled_templates: compiled_templates, runtime_directory: runtime_directory,
      logger: logger
    )
  end

  let(:logger) { nil }
  let(:runtime_directory) { @runtime_directory }
  let(:template_defs) do
    {
      templ0: ConfigOMat::Template.new(src: 'foo.conf', dst: 'foo.conf'),
      templ1: ConfigOMat::Template.new(src: 'bar.conf', dst: 'bar.conf')
    }
  end

  let(:applied_profiles) do
    {
      source0: ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        nil
      ),
      source1: ConfigOMat::LoadedProfile.new(
        ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
        {
          secret: ConfigOMat::LoadedSecret.new(
            :secret, 'test', '96444d8e-b27a-4b15-be2a-dc217b936bee', { answer: 91 }.to_json, 'application/json'
          )
        }
      )
    }
  end

  let(:applying_profile) { nil }

  let(:dependencies) do
    {
      templ0: Set.new([:service0, :service1]),
      templ1: Set.new([:service1, :service2])
    }
  end

  let(:generated_templates) do
    {
      templ0: ConfigOMat::GeneratedTemplate.new(%()),
      templ1: ConfigOMat::GeneratedTemplate.new(%(versions:\n  source0: '1'\n  source1: '2'\n))
    }
  end

  let(:compiled_templates) do
    state = ConfigOMat::Configurator::Memory.new(
      configuration_directory: File.expand_path(File.join(__dir__, '..', '..', '..', 'fixtures', 'config', 'templates_happy')),
      template_defs: template_defs
    )
    ConfigOMat::Op::CompileTemplates.call(state)
    state.compiled_templates
  end

  context 'with the happy path' do
    it 'writes templates into runtime_directory' do
      expect(File.read(File.join(runtime_directory, 'foo.conf'))).to eq %(answer: 42\nvalue: 181\nsecret: 91\n)
    end

    it 'updates state' do
      expect(state).to have_attributes(
        services_to_reload: [:service0, :service1],
        generated_templates: {
          templ0: ConfigOMat::GeneratedTemplate.new(%(answer: 42\nvalue: 181\nsecret: 91\n)),
          templ1: generated_templates[:templ1]
        }
      )
    end

    context 'when applying a profile' do
      let(:applying_profile) do
        ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source1, '3', { answer: 255 }.to_json, 'application/json'),
          {
            secret: ConfigOMat::LoadedSecret.new(
              :secret, 'test', '96444d8e-b27a-4b15-be2a-dc217b936bee', { answer: 191 }.to_json, 'application/json'
            )
          }
        )
      end

      it 'uses the profile being applied' do
        expect(File.read(File.join(runtime_directory, 'bar.conf'))).to eq %(versions:\n  source0: '1'\n  source1: '3'\n)
      end

      it 'updates state' do
        expect(state).to have_attributes(
          services_to_reload: [:service0, :service1, :service2],
          generated_templates: {
            templ0: ConfigOMat::GeneratedTemplate.new(%(answer: 42\nvalue: 255\nsecret: 191\n)),
            templ1: ConfigOMat::GeneratedTemplate.new(%(versions:\n  source0: '1'\n  source1: '3'\n))
          }
        )
      end

      context 'when the profile is errored' do
        let(:applying_profile) do
          ConfigOMat::LoadedProfile.new(
            ConfigOMat::LoadedAppconfigProfile.new(:source1, '3', '{"answer: 181', 'application/json'),
            nil
          )
        end

        it 'errors' do
          expect(result.errors).to match(
            source1: [{ contents: [an_instance_of(JSON::ParserError)] }]
          )
        end
      end
    end

    context 'with a logger', logger: true do
      it 'logs changed templates' do
        expect(@messages).to include(
          contain_exactly(
            :notice, :template_update,
            a_hash_including(template: :templ0, file: File.join(runtime_directory, template_defs[:templ0].dst))
          )
        )
      end
    end
  end

  context 'with a template that has no declared dependencies' do
    let(:template_defs) do
      {
        templ0: ConfigOMat::Template.new(src: 'foo.conf', dst: 'foo.conf'),
        templ1: ConfigOMat::Template.new(src: 'bar.conf', dst: 'bar.conf'),
        templ2: ConfigOMat::Template.new(src: 'other.conf', dst: 'other.conf')
      }
    end

    it 'writes templates into runtime_directory' do
      expect(File.read(File.join(runtime_directory, 'other.conf'))).to eq %(answer: 42\nvalue: 181\n)
    end

    it 'updates state' do
      expect(state).to have_attributes(
        services_to_reload: [:service0, :service1],
        generated_templates: {
          templ0: ConfigOMat::GeneratedTemplate.new(%(answer: 42\nvalue: 181\nsecret: 91\n)),
          templ1: generated_templates[:templ1],
          templ2: ConfigOMat::GeneratedTemplate.new(%(answer: 42\nvalue: 181\n))
        }
      )
    end
  end

  context 'when a template errors' do
    let(:applied_profiles) do
      {
        source0: ConfigOMat::LoadedProfile.new(
          ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
          nil
        )
      }
    end

    it 'errors' do
      expect(result.errors).to match(
        templ1: [an_instance_of(NoMethodError)]
      )
    end
  end
end

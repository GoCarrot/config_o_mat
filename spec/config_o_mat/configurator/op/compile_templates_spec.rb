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

require 'config_o_mat/configurator/op/compile_templates'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::CompileTemplates do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      configuration_directory: expanded_conf_dir,
      template_defs: template_defs
    )
  end

  let(:expanded_conf_dir) do
    File.expand_path(File.join(__dir__, '..', '..', '..', 'fixtures', 'config', configuration_directory))
  end

  let(:template_defs) do
    {
      templ0: ConfigOMat::Template.new(src: 'foo.conf', dst: 'foo.conf'),
      templ1: ConfigOMat::Template.new(src: 'bar.conf', dst: 'bar.conf')
    }
  end

  let(:profiles) do
    {
      source0: ConfigOMat::LoadedProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
      source1: ConfigOMat::LoadedProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json')
    }
  end

  context 'with the happy path' do
    let(:configuration_directory) { 'templates_happy' }

    it 'compiles the templates' do
      expect(
        state.compiled_templates.transform_values { |t| t.render(profiles) }
      ).to match(
        templ0: %(answer: 42\nvalue: 181\n),
        templ1: %(versions:\n  source0: '1'\n  source1: '2'\n)
      )
    end
  end

  context 'with a missing template' do
    let(:configuration_directory) { 'missing_templates' }

    it 'errors' do
      expect(result.errors).to match(
        File.join(expanded_conf_dir, 'templates', 'foo.conf') => [an_instance_of(Errno::ENOENT)],
        File.join(expanded_conf_dir, 'templates', 'bar.conf') => [an_instance_of(Errno::ENOENT)]
      )
    end
  end

  context 'with a broken erb template' do
    let(:configuration_directory) { 'invalid_templates' }

    it 'errors' do
      expect(result.errors).to match(
        File.join(expanded_conf_dir, 'templates', 'foo.conf') => [an_instance_of(SyntaxError)],
        File.join(expanded_conf_dir, 'templates', 'bar.conf') => [an_instance_of(SyntaxError)]
      )
    end
  end
end

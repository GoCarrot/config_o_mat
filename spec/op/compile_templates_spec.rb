# frozen_string_literal: true

require 'op/compile_templates'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::CompileTemplates do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      configuration_directory: expanded_conf_dir,
      template_defs: template_defs
    )
  end

  let(:expanded_conf_dir) do
    File.expand_path(File.join(__dir__, '..', 'fixtures', 'config', configuration_directory))
  end

  let(:template_defs) do
    {
      templ0: Template.new(src: 'foo.conf', dst: 'foo.conf'),
      templ1: Template.new(src: 'bar.conf', dst: 'bar.conf')
    }
  end

  let(:profiles) do
    {
      source0: LoadedProfile.new('1', answer: 42),
      source1: LoadedProfile.new('2', answer: 181)
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

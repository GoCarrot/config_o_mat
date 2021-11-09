# frozen_string_literal: true

require 'op/generate_all_templates'

require 'configurator_memory'
require 'configurator_types'

require 'tmpdir'

RSpec.describe Op::GenerateAllTemplates do
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
    ConfiguratorMemory.new(
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
      templ0: Template.new(src: 'foo.conf', dst: 'foo.conf'),
      templ1: Template.new(src: 'bar.conf', dst: 'bar.conf')
    }
  end

  let(:applied_profiles) do
    {
      source0: LoadedProfile.new(:source0, '1', answer: 42),
      source1: LoadedProfile.new(:source1, '2', answer: 181)
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
      templ0: GeneratedTemplate.new(%()),
      templ1: GeneratedTemplate.new(%(versions:\n  source0: '1'\n  source1: '2'\n))
    }
  end

  let(:compiled_templates) do
    state = ConfiguratorMemory.new(
      configuration_directory: File.expand_path(File.join(__dir__, '..', 'fixtures', 'config', 'templates_happy')),
      template_defs: template_defs
    )
    Op::CompileTemplates.call(state)
    state.compiled_templates
  end

  context 'with the happy path' do
    it 'writes templates into runtime_directory' do
      expect(File.read(File.join(runtime_directory, 'foo.conf'))).to eq %(answer: 42\nvalue: 181\n)
    end

    it 'updates state' do
      expect(state).to have_attributes(
        services_to_reload: Set.new([:service0, :service1]),
        generated_templates: {
          templ0: GeneratedTemplate.new(%(answer: 42\nvalue: 181\n)),
          templ1: generated_templates[:templ1]
        }
      )
    end

    context 'when applying a profile' do
      let(:applying_profile) do
        LoadedProfile.new(:source1, '3', answer: 255)
      end

      it 'uses the profile being applied' do
        expect(File.read(File.join(runtime_directory, 'bar.conf'))).to eq %(versions:\n  source0: '1'\n  source1: '3'\n)
      end

      it 'updates state' do
        expect(state).to have_attributes(
          services_to_reload: Set.new([:service0, :service1, :service2]),
          generated_templates: {
            templ0: GeneratedTemplate.new(%(answer: 42\nvalue: 255\n)),
            templ1: GeneratedTemplate.new(%(versions:\n  source0: '1'\n  source1: '3'\n))
          }
        )
      end
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs changed templates' do
        expect(@messages).to contain_exactly(
          contain_exactly(
            :notice, :template_update,
            a_hash_including(template: :templ0, file: File.join(runtime_directory, template_defs[:templ0].dst))
          )
        )
      end
    end
  end

  context 'when a template errors' do
    let(:applied_profiles) do
      {
        source0: LoadedProfile.new(:source0, '1', answer: 42),
      }
    end

    it 'errors' do
      expect(result.errors).to match(
        templ1: [an_instance_of(NoMethodError)]
      )
    end
  end
end

# frozen_string_literal: true

require 'op/load_meta_config'

require 'configurator_memory'
require 'configurator_types'

RSpec.describe Op::LoadMetaConfig do
  def perform
    described_class.call(state)
  end

  before { @result = perform }
  
  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      configuration_directory: expanded_conf_dir
    )
  end

  let(:expanded_conf_dir) do
    File.expand_path(File.join(__dir__, '..', 'fixtures', 'config', configuration_directory))
  end

  context 'with the happy path' do
    let(:configuration_directory) { 'happy_path' }

    it 'loads configuration' do
      templates = {
        templ0: Template.new(src: 'foo2.conf', dst: 'foo.conf'),
        templ1: Template.new(src: 'bar.conf', dst: 'bar.conf'),
        templ2: Template.new(src: 'baz.conf', dst: 'baz.conf'),
        templ3: Template.new(src: '3.conf', dst: '3.conf')
      }

      services = {
        test0: Service.new(
          systemd_unit: 'test0', restart_mode: 'flip_flop', templates: [
            'templ0', 'templ1', 'templ2'
          ]
        ),
        test1: Service.new(
          systemd_unit: 'test1', restart_mode: 'restart', templates: [
            'templ0', 'templ2'
          ]
        ),
        test2: Service.new(
          systemd_unit: 'test2', restart_mode: 'restart', templates: [
            'templ0'
          ]
        )
      }

      expect(state).to have_attributes(
        profile_defs: match({
          source0: Profile.new(application: 'test', environment: 'test', profile: 'test'),
          source1: Profile.new(application: 'bar', environment: 'test', profile: 'test'),
          source2: Profile.new(application: 'baz', environment: 'baz', profile: 'other')
        }),
        template_defs: match(templates),
        service_defs: match(services),
        dependencies: match({
          templ0: Set.new([services[:test0], services[:test1], services[:test2]]),
          templ1: Set.new([services[:test0]]),
          templ2: Set.new([services[:test0], services[:test1]])
        })
      )
    end
  end
end

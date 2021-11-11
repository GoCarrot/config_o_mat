# frozen_string_literal: true

require 'op/reload_one_service'

require 'configurator_memory'
require 'configurator_types'

require 'tmpdir'

RSpec.describe Op::ReloadOneService do
  def perform
    described_class.call(state)
  end

  before do
    @runtime_directory = Dir.mktmpdir
    touch_files.each do |file|
      path = File.join(runtime_directory, file)
      FileUtils.touch(path)
      @stat ||= {}
      @stat[file] = File.stat(path)
    end
    @result = perform
  end

  after do
    FileUtils.remove_entry @runtime_directory
  end

  subject(:result) { @result }

  let(:state) do
    ConfiguratorMemory.new(
      runtime_directory: runtime_directory,
      service_defs: service_defs,
      services_to_reload: services_to_reload,
      logger: logger
    )
  end

  let(:runtime_directory) { @runtime_directory }
  let(:service_defs) do
    {
      service0: Service.new(systemd_unit: 'test', restart_mode: 'restart', templates: ['templ0']),
      service1: Service.new(systemd_unit: 'other', restart_mode: 'restart', templates: ['templ1'])
    }
  end

  let(:services_to_reload) { %i[service0 service1] }
  let(:touch_files) { [] }
  let(:logger) { nil }

  context 'without a reload file present' do
    it 'touches the reload file' do
      expect { File.stat(File.join(runtime_directory, 'other.restart')) }.not_to raise_error
    end

    it 'updates services_to_reload' do
      expect(state).to have_attributes(
        services_to_reload: %i[service0]
      )
    end
  end

  context 'with a reload file present' do
    let(:touch_files) { ['other.restart'] }

    it 'touches the reload file' do
      expect(File.stat(File.join(runtime_directory, 'other.restart'))).to be > @stat['other.restart']
    end

    it 'updates services_to_reload' do
      expect(state).to have_attributes(
        services_to_reload: %i[service0]
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

    it 'logs a service reload' do
      expect(@messages).to include(
        contain_exactly(:notice, :service_restart, a_hash_including(name: :service1, systemd_unit: 'other'))
      )
    end
  end
end

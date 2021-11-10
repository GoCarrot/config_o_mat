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
      configuration_directory: expanded_conf_dir,
      logs_directory: logs_directory,
      logger: logger
    )
  end

  let(:expanded_conf_dir) do
    File.expand_path(File.join(__dir__, '..', 'fixtures', 'config', configuration_directory))
  end

  let(:logs_directory) { '/var/log/configurator' }

  let(:logger) { LogsForMyFamily::Logger.new }

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
        }),
        refresh_interval: 20,
        client_id: 'bar',
        logger: an_instance_of(LogsForMyFamily::Logger).and(have_attributes(
          level: :debug,
          backends: contain_exactly(an_instance_of(StdoutLogWriter))
        )),
        retry_count: 6,
        retries_left: 6,
        retry_wait: 12
      )
    end
  end

  context 'with log file output' do
    let(:configuration_directory) { 'log_file' }

    it 'configures the logger' do
      expect(state.logger).to be_an_instance_of(LogsForMyFamily::Logger).and(have_attributes(
        level: :notice,
        backends: contain_exactly(
          an_instance_of(FileLogWriter).and(
            have_attributes(file_path: File.join(logs_directory, 'test.log'))
          )
        )
      ))
    end

    context 'without logs_directory set' do
      let(:logs_directory) { nil }

      it 'errors' do
        expect(result.errors).to match(
          log_type: ['must set logs directory with -l or $LOGS_DIRECTORY to set log_type to file']
        )
      end
    end
  end

  context 'with log_type set to file but no log_file' do
    let(:configuration_directory) { 'log_type_file_no_file' }

    it 'configures the logger to log to configurator.log' do
      expect(state.logger).to be_an_instance_of(LogsForMyFamily::Logger).and(have_attributes(
        level: :notice,
        backends: contain_exactly(
          an_instance_of(FileLogWriter).and(
            have_attributes(file_path: File.join(logs_directory, 'configurator.log'))
          )
        )
      ))
    end

    context 'without logs_directory set' do
      let(:logs_directory) { nil }

      it 'errors' do
        expect(result.errors).to match(
          log_type: ['must set logs directory with -l or $LOGS_DIRECTORY to set log_type to file']
        )
      end
    end
  end

  context 'with defaults' do
    let(:configuration_directory) { 'use_defaults' }

    it 'uses default config and logger' do
      expect(state).to have_attributes(
        refresh_interval: 5,
        client_id: match(/\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89aAbB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}\z/),
        logger: have_attributes(
          backends: [an_instance_of(StdoutLogWriter)]
        ),
        retry_count: 3,
        retries_left: 3,
        retry_wait: 2
      )
    end

    context 'with INVOCATION_ID set in env' do
      let(:invocation_id) { SecureRandom.uuid }
      let(:state) do
        ConfiguratorMemory.new(
          configuration_directory: expanded_conf_dir,
          env: { 'INVOCATION_ID' => invocation_id }
        )
      end

      it 'uses the invocation id as the client id' do
        expect(state).to have_attributes(
          refresh_interval: 5,
          client_id: invocation_id
        )
      end
    end
  end

  context 'with a missing template dependency' do
    let(:configuration_directory) { 'missing_dependency' }

    it 'errors on dependencies' do
      expect(result.errors).to match(
        services: [{test0: 'references undefined template templ1'}]
      )
    end
  end

  context 'with an unparsable file' do
    let(:configuration_directory) { 'parse_error' }

    it 'errors on the file' do
      expect(result.errors).to match(
        File.join(expanded_conf_dir, '00_base.yml.conf') => [an_instance_of(Psych::SyntaxError)]
      )
    end
  end

  context 'with a validation error' do
    let(:configuration_directory) { 'validation_error' }

    it 'errors on the bad config' do
      expect(result.errors).to match(
        services: [{test0: an_instance_of(ConfigItem::ValidationError)}]
      )
    end
  end

  context 'with an invalid log type' do
    let(:configuration_directory) { 'invalid_log_type' }

    it 'errors on log type' do
      expect(result.errors).to match(
        log_type: ['must be one of ["stdout", "file"]']
      )
    end
  end

  context 'with an invalid log level' do
    let(:configuration_directory) { 'invalid_log_level' }

    it 'errors on log_level' do
      expect(result.errors).to match(
        log_level: [include('must be one of')]
      )
    end
  end
end

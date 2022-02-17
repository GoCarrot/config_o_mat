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

require 'config_o_mat/shared/op/load_meta_config'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

RSpec.describe ConfigOMat::Op::LoadMetaConfig do
  def perform
    described_class.call(state)
  end

  before do
    @bus = {
      ConfigOMat::SystemdInterface::SERVICE_NAME => {
        ConfigOMat::SystemdInterface::OBJECT_PATH => {
          ConfigOMat::SystemdInterface::MANAGER_INTERFACE => {}
        }
      }
    }
    allow(DBus).to receive(:system_bus).and_return(@bus)
    @double = instance_double(ConfigOMat::SystemdInterface)
    allow(ConfigOMat::SystemdInterface).to receive(:new).with(@bus).and_return(@double)

    @new_logger_messages = []
    @stdout_logger_proc =  proc { |level_name, event_type, merged_data| @new_logger_messages << [level_name, event_type, merged_data] }
    allow(ConfigOMat::StdoutLogWriter).to receive(:new).and_return(@stdout_logger_proc)
    @result = perform
  end

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      configuration_directory: expanded_conf_dir,
      logs_directory: logs_directory,
      logger: logger
    )
  end

  let(:expanded_conf_dir) do
    File.expand_path(File.join(__dir__, '..', '..', '..', 'fixtures', 'config', configuration_directory))
  end

  let(:logs_directory) { '/var/log/configurator' }

  let(:logger) { LogsForMyFamily::Logger.new }

  context 'with the happy path' do
    let(:logger) { nil }
    let(:configuration_directory) { 'happy_path' }

    it 'loads configuration' do
      templates = {
        templ0: ConfigOMat::Template.new(src: 'foo2.conf', dst: 'foo.conf'),
        templ1: ConfigOMat::Template.new(src: 'bar.conf', dst: 'bar.conf'),
        templ2: ConfigOMat::Template.new(src: 'baz.conf', dst: 'baz.conf'),
        templ3: ConfigOMat::Template.new(src: '3.conf', dst: '3.conf')
      }

      services = {
        test0: ConfigOMat::Service.new(
          systemd_unit: 'test0', restart_mode: 'flip_flop', templates: [
            'templ0', 'templ1', 'templ2'
          ]
        ),
        test1: ConfigOMat::Service.new(
          systemd_unit: 'test1', restart_mode: 'restart', templates: [
            'templ0', 'templ2'
          ]
        ),
        test2: ConfigOMat::Service.new(
          systemd_unit: 'test2', restart_mode: 'restart', templates: [
            'templ0'
          ]
        )
      }

      expect(state).to have_attributes(
        profile_defs: match({
          source0: ConfigOMat::Profile.new(application: 'test', environment: 'test', profile: 'test'),
          source1: ConfigOMat::Profile.new(application: 'bar', environment: 'test', profile: 'test'),
          source2: ConfigOMat::Profile.new(application: 'baz', environment: 'baz', profile: 'other')
        }),
        template_defs: match(templates),
        service_defs: match(services),
        dependencies: match({
          templ0: Set.new([:test0, :test1, :test2]),
          templ1: Set.new([:test0]),
          templ2: Set.new([:test0, :test1])
        }),
        refresh_interval: 20,
        client_id: 'bar',
        logger: an_instance_of(LogsForMyFamily::Logger).and(have_attributes(
          level: :debug,
          backends: contain_exactly(@stdout_logger_proc)
        )),
        retry_count: 6,
        retries_left: 6,
        retry_wait: 12,
        region: 'us-east-1',
        systemd_interface: @double
      )
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end


      it 'logs the log config to be applied' do
        expect(@messages).to include(
          contain_exactly(
            :info, :log_config, a_hash_including(
              configuration: {
                log_level: 'debug'
              }
            )
          )
        )
      end

      it 'logs the config to be applied to the configured new_logger_messages' do
        expect(@new_logger_messages).to include(
          contain_exactly(
            :info, :parsed_config, a_hash_including(
              configuration: {
                client_id: 'bar',
                log_level: 'debug',
                refresh_interval: 20,
                retry_count: 6,
                retry_wait: 12,
                region: 'us-east-1',
                services: {
                  test0: {
                    systemd_unit: 'test0',
                    restart_mode: 'flip_flop',
                    templates: %w[templ0 templ1 templ2]
                  },
                  test1: {
                    systemd_unit: 'test1',
                    restart_mode: 'restart',
                    templates: %w[templ0 templ2]
                  },
                  test2: {
                    systemd_unit: 'test2',
                    restart_mode: 'restart',
                    templates: %w[templ0]
                  }
                },
                templates: {
                  templ0: {
                    src: 'foo2.conf',
                    dst: 'foo.conf'
                  },
                  templ1: {
                    src: 'bar.conf',
                    dst: 'bar.conf'
                  },
                  templ2: {
                    src: 'baz.conf',
                    dst: 'baz.conf'
                  },
                  templ3: {
                    src: '3.conf',
                    dst: '3.conf'
                  }
                },
                profiles: {
                  source0: {
                    application: 'test',
                    environment: 'test',
                    profile: 'test'
                  },
                  source1: {
                    application: 'bar',
                    environment: 'test',
                    profile: 'test'
                  },
                  source2: {
                    application: 'baz',
                    environment: 'baz',
                    profile: 'other'
                  }
                }
              }
            )
          )
        )
      end
    end
  end

  context 'with log file output' do
    let(:configuration_directory) { 'log_file' }

    it 'configures the logger' do
      expect(state.logger).to be_an_instance_of(LogsForMyFamily::Logger).and(have_attributes(
        level: :notice,
        backends: contain_exactly(
          an_instance_of(ConfigOMat::FileLogWriter).and(
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
          an_instance_of(ConfigOMat::FileLogWriter).and(
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
          backends: [@stdout_logger_proc]
        ),
        retry_count: 3,
        retries_left: 3,
        retry_wait: 2,
        region: nil
      )
    end

    context 'with INVOCATION_ID set in env' do
      let(:invocation_id) { SecureRandom.uuid }
      let(:state) do
        ConfigOMat::Configurator::Memory.new(
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
        services: [{test0: an_instance_of(ConfigOMat::ConfigItem::ValidationError)}]
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

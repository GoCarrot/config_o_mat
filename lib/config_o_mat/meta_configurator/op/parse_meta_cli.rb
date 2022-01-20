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

require 'lifecycle_vm/op_base'

require 'optparse'

module ConfigOMat
  module Op
    class ParseMetaCli < LifecycleVM::OpBase
      DEFAULT_SYSTEMD_DIRECTORY = '/run/systemd/system'

      reads :argv, :env
      writes :configuration_directory, :runtime_directory, :logs_directory, :systemd_directory, :early_exit

      # Add expand_path to string because the safe accessor is nice to use.
      module CoreExt
        refine String do
          def expand_path
            File.expand_path(self)
          end
        end
      end

      using CoreExt

      def call
        self.early_exit = false

        parser = OptionParser.new do |opts|
          opts.on('-v', '--version', 'Display the version') do
            self.early_exit = true
          end

          opts.on('-h', '--help', 'Prints this help') do
            puts opts
            self.early_exit = true
          end

          opts.on(
            '-c', '--configuration-directory directory',
            'Read configuration from the given directory instead of from $CONFIGURATION_DIRECTORY'
          ) do |dir|
            self.configuration_directory = dir
          end

          opts.on(
            '-r', '--runtime-directory directory',
            'Use the given directory for writing templates instead of $RUNTIME_DIRECTORY'
          ) do |dir|
            self.runtime_directory = dir
          end

          opts.on(
            '-l', '--logs-directory directory',
            'Use the given directory for writing log files instead of $LOGS_DIRECTORY'
          ) do |dir|
            self.logs_directory = dir
          end

          opts.on(
            '-s', '--systemd-directory directory',
            "Write out systemd configuration to the given directory instead of #{DEFAULT_SYSTEMD_DIRECTORY}"
          ) do |dir|
            self.systemd_directory = dir
          end
        end

        parser.parse(argv)

        self.configuration_directory ||= env['CONFIGURATION_DIRECTORY']
        self.runtime_directory ||= env['RUNTIME_DIRECTORY']
        self.logs_directory ||= env['LOGS_DIRECTORY']
        self.systemd_directory ||= DEFAULT_SYSTEMD_DIRECTORY

        self.configuration_directory = configuration_directory&.expand_path
      end

      def validate
        return if early_exit

        if configuration_directory.nil? || configuration_directory.empty?
          error :configuration_directory, 'must be present'
        end

        error :runtime_directory, 'must be present' if runtime_directory.nil? || runtime_directory.empty?
      end
    end
  end
end

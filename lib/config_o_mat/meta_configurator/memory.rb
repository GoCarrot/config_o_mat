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

require 'lifecycle_vm/memory'

module ConfigOMat
  module MetaConfigurator
    class Memory < LifecycleVM::Memory
      attr_accessor :argv, :env, :early_exit, :configuration_directory, :runtime_directory,
                    :systemd_directory, :logs_directory, :profile_defs,
                    :template_defs, :service_defs, :dependencies, :refresh_interval,
                    :client_id, :retry_count, :retries_left, :retry_wait,
                    :region, :systemd_interface

      def initialize(
        argv: [],
        env: {},
        early_exit: false,
        configuration_directory: nil,
        runtime_directory: nil,
        logs_directory: nil,
        systemd_directory: nil,
        profile_defs: {},
        template_defs: {},
        service_defs: {},
        dependencies: {},
        refresh_interval: 5,
        client_id: '',
        logger: nil,
        retry_count: 3,
        retries_left: 3,
        retry_wait: 2,
        region: nil,
        systemd_interface: nil
      )
        super()

        @argv = argv
        @env = env
        @early_exit = early_exit
        @configuration_directory = configuration_directory
        @runtime_directory = runtime_directory
        @logs_directory = logs_directory
        @systemd_directory = systemd_directory
        @profile_defs = profile_defs
        @template_defs = template_defs
        @service_defs = service_defs
        @dependencies = dependencies
        @refresh_interval = refresh_interval
        @client_id = client_id
        @logger = logger
        @retry_count = retry_count
        @retries_left = retries_left
        @retry_wait = retry_wait
        @region = region
        @systemd_interface = systemd_interface
      end
    end
  end
end

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
  module Configurator
    class Memory < LifecycleVM::Memory
      attr_accessor :argv, :env, :early_exit, :configuration_directory,
                    :runtime_directory, :logs_directory, :run_count, :profile_defs,
                    :template_defs, :service_defs, :dependencies, :refresh_interval,
                    :client_id, :compiled_templates, :applied_profiles, :applying_profile,
                    :generated_templates, :services_to_reload, :profiles_to_apply,
                    :last_refresh_time, :next_state, :retry_count, :retries_left, :retry_wait,
                    :region, :appconfig_client, :secretsmanager_client, :s3_client,
                    :systemd_interface, :secrets_loader_memory, :gc_compact, :gc_stat,
                    :fallback_s3_bucket

      def initialize(
        argv: [],
        env: {},
        early_exit: false,
        configuration_directory: nil,
        runtime_directory: nil,
        logs_directory: nil,
        run_count: 0,
        profile_defs: {},
        template_defs: {},
        service_defs: {},
        dependencies: {},
        refresh_interval: 5,
        client_id: '',
        logger: nil,
        compiled_templates: {},
        applied_profiles: {},
        profiles_to_apply: [],
        applying_profile: nil,
        generated_templates: {},
        services_to_reload: Set.new,
        last_refresh_time: 0,
        next_state: :running,
        retry_count: 3,
        retries_left: 3,
        retry_wait: 2,
        region: nil,
        appconfig_client: nil,
        secretsmanager_client: nil,
        s3_client: nil,
        systemd_interface: nil,
        secrets_loader_memory: nil,
        gc_compact: 0,
        gc_stat: 0,
        fallback_s3_bucket: nil
      )
        super()

        @argv = argv
        @env = env
        @early_exit = early_exit
        @configuration_directory = configuration_directory
        @runtime_directory = runtime_directory
        @logs_directory = logs_directory
        @run_count = run_count
        @profile_defs = profile_defs
        @template_defs = template_defs
        @service_defs = service_defs
        @dependencies = dependencies
        @refresh_interval = refresh_interval
        @client_id = client_id
        @logger = logger
        @compiled_templates = compiled_templates
        @applied_profiles = applied_profiles
        @profiles_to_apply = profiles_to_apply
        @applying_profile = applying_profile
        @generated_templates = generated_templates
        @services_to_reload = services_to_reload
        @last_refresh_time = last_refresh_time
        @next_state = next_state
        @retry_count = retry_count
        @retries_left = retries_left
        @retry_wait = retry_wait
        @region = region
        @appconfig_client = appconfig_client
        @secretsmanager_client = secretsmanager_client
        @s3_client = s3_client
        @systemd_interface = systemd_interface
        @secrets_loader_memory = secrets_loader_memory
        @gc_compact = gc_compact
        @gc_stat = gc_stat
        @fallback_s3_bucket = fallback_s3_bucket
      end
    end
  end
end

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

require 'config_o_mat/secrets_loader'

module ConfigOMat
  module Op
    class RefreshAllProfiles < LifecycleVM::OpBase
      reads :profile_defs, :applied_profiles, :client_id, :appconfig_client, :secrets_loader_memory,
            :secretsmanager_client, :s3_client
      writes :profiles_to_apply, :last_refresh_time, :secrets_loader_memory

      def call
        self.profiles_to_apply = []
        self.last_refresh_time = Time.now.to_i

        profile_defs.each do |(profile_name, definition)|
          if definition.kind_of?(ConfigOMat::Profile)
            refresh_appconfig_profile(profile_name, definition)
          elsif definition.kind_of?(ConfigOMat::FacterProfile)
            refresh_facter_profile(profile_name)
          else
            error profile_name, "unknown profile type #{definition.class.name}"
          end
        end
      end

    private

      def refresh_facter_profile(profile_name)
        current_version = applied_profiles&.fetch(profile_name, nil)&.version
        new_profile = ConfigOMat::LoadedFacterProfile.new(profile_name)

        return if new_profile.version == current_version

        logger&.notice(
          :updated_profile,
          name: profile_name, previous_version: current_version, new_version: new_profile.version
        )

        profiles_to_apply << LoadedProfile.new(new_profile, nil)
      end

      def request_from_s3(profile_name, definition, ignore_errors)
        fallback = definition.s3_fallback
        begin
          s3_response = s3_client.get_object(bucket: fallback[:bucket], key: fallback[:object])
          OpenStruct.new(
            content: s3_response.body,
            content_type: s3_response.content_type,
            configuration_version: s3_response.version_id
          )
        rescue StandardError => e
          logger&.error(:s3_fallback_load_failed, name: profile_name, reason: e)
          error profile_name, e unless ignore_errors
          nil
        end
      end

      def refresh_appconfig_profile(profile_name, definition)
        request = {
          application: definition.application, environment: definition.environment,
          configuration: definition.profile, client_id: client_id
        }

        current_version = applied_profiles&.fetch(profile_name, nil)&.version
        request[:client_configuration_version] = current_version if current_version
        fallback = false

        response =
          begin
            appconfig_client.get_configuration(request)
          rescue StandardError => e
            if definition.s3_fallback
              fallback = true
              logger&.error(:s3_fallback_request, name: profile_name, reason: e)
              request_from_s3(profile_name, definition, false)
            else
              error profile_name, e
              nil
            end
          end

        return if response.nil?

        loaded_version = response.configuration_version
        return if current_version && loaded_version == current_version

        logger&.notice(
          :updated_profile,
          name: profile_name, previous_version: current_version, new_version: loaded_version
        )

        profile = LoadedAppconfigProfile.new(
          profile_name, loaded_version, response.content.read, response.content_type, fallback
        )

        if profile.chaos_config? && !fallback
          logger&.notice(:chaos_config_requested, name: profile_name)
          if !definition.s3_fallback
            logger&.error(:refusing_chaos_config, name: profile_name, reason: 'no s3 fallback provided')
          else
            response = request_from_s3(profile_name, definition, true)
            if !response
              logger&.error(:chaos_config_load_failed, name: profile_name)
            else
              loaded_version = response.configuration_version
              logger&.notice(:chaos_config_profile_loaded, name: profile_name, new_version: loaded_version)
              profile = LoadedAppconfigProfile.new(
                profile_name, loaded_version, response.content.read, response.content_type, true
              )
            end
          end
        end

        loaded_secrets = nil

        if !profile.secret_defs.empty?
          self.secrets_loader_memory ||= ConfigOMat::SecretsLoader::Memory.new(secretsmanager_client: secretsmanager_client)
          secrets_loader_memory.update_secret_defs_to_load(profile.secret_defs.values)

          vm = ConfigOMat::SecretsLoader::VM.new(secrets_loader_memory).call

          if vm.errors?
            error :"#{profile_name}_secrets", vm.errors
            return
          end

          loaded_secrets = secrets_loader_memory.loaded_secrets.each_with_object({}) do |(key, value), hash|
            hash[value.name] = value
          end
        end

        profiles_to_apply << LoadedProfile.new(profile, loaded_secrets)
      end
    end
  end
end

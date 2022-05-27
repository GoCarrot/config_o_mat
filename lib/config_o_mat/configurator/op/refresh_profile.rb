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

module ConfigOMat
  module Op
    class RefreshProfile < LifecycleVM::OpBase
      reads :profile_defs, :client_id, :applying_profile, :appconfig_client, :secretsmanager_client,
            :secrets_loader_memory, :s3_client, :fallback_s3_bucket
      writes :applying_profile, :secrets_loader_memory

      def call
        if applying_profile.loaded_profile_data.kind_of?(ConfigOMat::LoadedAppconfigProfile)
          refresh_appconfig_profile
        elsif applying_profile.loaded_profile_data.kind_of?(ConfigOMat::LoadedFacterProfile)
          refresh_facter_profile
        end
      end

    private

      def refresh_facter_profile
        profile_name = applying_profile.name
        profile_version = applying_profile.version
        definition = profile_defs[profile_name]
        new_profile = ConfigOMat::LoadedFacterProfile.new(profile_name)

        if new_profile.version == profile_version
          logger&.warning(
            :no_update,
            name: profile_name, version: profile_version
          )
          return
        end

        logger&.notice(
          :updated_profile,
          name: profile_name, previous_version: profile_version, new_version: new_profile.version
        )

        self.applying_profile = LoadedProfile.new(new_profile, nil)
      end

      def request_from_s3(profile_name, definition)
        begin
          s3_response = s3_client.get_object(bucket: fallback_s3_bucket, key: definition.s3_fallback)
          OpenStruct.new(
            content: s3_response.body,
            content_type: s3_response.content_type,
            configuration_version: s3_response.version_id
          )
        rescue StandardError => e
          error profile_name, e
          nil
        end
      end

      def refresh_appconfig_profile
        profile_name = applying_profile.name
        profile_version = applying_profile.version
        definition = profile_defs[profile_name]
        request = {
          application: definition.application, environment: definition.environment,
          configuration: definition.profile, client_id: client_id,
          client_configuration_version: profile_version
        }
        fallback = false

        response =
          begin
            appconfig_client.get_configuration(request)
          rescue StandardError => e
            if definition.s3_fallback
              fallback = true
              logger&.error(:s3_fallback_request, name: profile_name, reason: e)
              request_from_s3(profile_name, definition)
            else
              error profile_name, e
              nil
            end
          end

        return if response.nil? || errors?
        loaded_version = response.configuration_version

        if loaded_version == profile_version
          logger&.warning(
            :no_update,
            name: profile_name, version: profile_version
          )
          return
        end

        logger&.notice(
          :updated_profile,
          name: profile_name, previous_version: profile_version, new_version: loaded_version
        )

        profile = LoadedAppconfigProfile.new(
          profile_name, loaded_version, response.content.read, response.content_type, fallback
        )

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

        self.applying_profile = LoadedProfile.new(profile, loaded_secrets)
      end
    end
  end
end

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
      reads :profile_defs, :client_id, :applying_profile, :appconfig_client
      writes :applying_profile

      def call
        profile_name = applying_profile.name
        profile_version = applying_profile.version
        definition = profile_defs[profile_name]
        request = {
          application: definition.application, environment: definition.environment,
          configuration: definition.profile, client_id: client_id,
          client_configuration_version: profile_version
        }

        response =
          begin
            appconfig_client.get_configuration(request)
          rescue StandardError => e
            error profile_name, e
            nil
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

        self.applying_profile = LoadedAppconfigProfile.new(
          profile_name, loaded_version, response.content.read, response.content_type
        )
      end
    end
  end
end

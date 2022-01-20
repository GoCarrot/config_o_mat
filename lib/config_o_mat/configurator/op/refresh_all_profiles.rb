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
    class RefreshAllProfiles < LifecycleVM::OpBase
      reads :profile_defs, :applied_profiles, :client_id, :appconfig_client
      writes :profiles_to_apply, :last_refresh_time

      def call
        self.profiles_to_apply = []
        self.last_refresh_time = Time.now.to_i

        profile_defs.each do |(profile_name, definition)|
          request = {
            application: definition.application, environment: definition.environment,
            configuration: definition.profile, client_id: client_id
          }

          current_version = applied_profiles&.fetch(profile_name, nil)&.version
          request[:client_configuration_version] = current_version if current_version

          response =
            begin
              appconfig_client.get_configuration(request)
            rescue StandardError => e
              error profile_name, e
              nil
            end

          next if response.nil?

          loaded_version = response.configuration_version
          next if current_version && loaded_version == current_version

          logger&.notice(
            :updated_profile,
            name: profile_name, previous_version: current_version, new_version: loaded_version
          )

          profiles_to_apply << LoadedProfile.new(
            profile_name, loaded_version, response.content.read, response.content_type
          )
        end
      end
    end
  end
end

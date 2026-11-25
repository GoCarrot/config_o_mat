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
    class CommitStagedProfile < LifecycleVM::OpBase
      reads :applied_profiles, :applying_profile, :rejected_profiles, :profiles_to_apply
      writes :applied_profiles, :applying_profile, :rejected_profiles, :profiles_to_apply

      def call
        # This happens in the first boot case, where we apply all profiles at once and so there's no
        # individual applying_profile.
        return if applying_profile.nil?

        applied_profiles[applying_profile.name] = applying_profile

        if rejected_profiles.delete(applying_profile.name)
          logger&.notice(:profile_rejection_cleared, name: applying_profile.name, profile_version: applying_profile.version)
        end

        self.applying_profile = nil

        # A rejected profile may only render alongside a newer version of this one, so give each another go.
        rejected_profiles.each_value do |rejected|
          next if profiles_to_apply.any? { |queued| queued.name == rejected.name }

          logger&.notice(:retrying_rejected_profile, name: rejected.name, profile_version: rejected.version)
          profiles_to_apply.unshift(rejected)
        end
      end
    end
  end
end

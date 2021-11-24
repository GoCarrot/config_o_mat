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

require 'lifecycle/op_base'

module Op
  class CommitStagedProfile < Lifecycle::OpBase
    reads :applied_profiles, :applying_profile
    writes :applied_profiles, :applying_profile

    def call
      # This happens in the first boot case, where we apply all profiles at once and so there's no
      # individual applying_profile.
      return if applying_profile.nil?

      applied_profiles[applying_profile.name] = applying_profile
      self.applying_profile = nil
    end
  end
end

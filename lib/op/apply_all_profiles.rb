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

module Op
  class ApplyAllProfiles < LifecycleVM::OpBase
    reads :profiles_to_apply, :applied_profiles
    writes :profiles_to_apply, :applied_profiles

    def call
      profiles_to_apply.each do |profile|
        applied_profiles[profile.name] = profile
        error profile.name, profile.errors if profile.errors?
      end

      self.profiles_to_apply = []
    end
  end
end

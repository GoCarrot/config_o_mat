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
  class StageOneProfile < Lifecycle::OpBase
    reads :profiles_to_apply
    writes :applying_profile, :profiles_to_apply

    def call
      self.applying_profile = profiles_to_apply.pop

      # We defer error checking to GenerateAllTemplates so that even if errored the profile gets set as
      # the applying_profile, which simplifies retry logic.
    end
  end
end

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

require 'lifecycle_vm/cond_base'

module ConfigOMat
  module Cond
    class RetriesLeft < LifecycleVM::CondBase
      reads :error_op, :retries_left, :applying_profile

      def call
        logger&.error(:op_failure, op: error_op.class.name, errors: error_op.errors)

        # If we aren't currently applying a profile then there's nothing for us to retry.
        return false if applying_profile.nil?

        # If we're out of retries, well, no more retrying
        return false if retries_left.zero?

        true
      end
    end
  end
end

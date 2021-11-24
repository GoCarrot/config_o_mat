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
  class WaitRetry < Lifecycle::OpBase
    reads :retry_wait, :retry_count, :retries_left
    writes :retries_left

    def call
      # Exponential backoff
      wait = retry_wait * (2**(retry_count - retries_left))

      # With jitter
      wait += rand(retry_wait + 1) - (retry_wait / 2.0)

      logger&.notice(:retry_wait, wait: wait)

      # Calling Kernel.sleep directly for easy test stubbing
      Kernel.sleep wait

      self.retries_left -= 1
    end
  end
end

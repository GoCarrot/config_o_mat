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

require 'sd_notify'

module ConfigOMat
  module Op
    class NextTick < LifecycleVM::OpBase
      PAUSE_INTERVAL = 1

      reads :last_refresh_time, :refresh_interval, :run_count, :retry_count
      writes :next_state, :run_count, :retries_left

      def call
        self.run_count += 1

        SdNotify.watchdog

        # If we got here then our retry process has succeeded.
        self.retries_left = retry_count

        # I'm calling Kernel.sleep directly so that tests can easily stub it out.
        Kernel.sleep PAUSE_INTERVAL

        if Time.now.to_i - last_refresh_time > refresh_interval
          self.next_state = :refreshing_profiles
        else
          self.next_state = :running
        end
      end
    end
  end
end

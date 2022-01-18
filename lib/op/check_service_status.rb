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
  class CheckServiceStatus < LifecycleVM::OpBase
    reads :service, :activating_instance, :activating_interface, :systemd_interface,
          :min_wait, :max_wait
    writes :activating_interface, :activation_status, :min_wait, :max_wait

    def call
      if min_wait > 0
        do_sleep(min_wait)
      else
        do_sleep(1)
      end

      if !activating_interface
        self.activating_interface = systemd_interface.unit_interface("#{service}#{activating_instance}")
      end

      if !activating_interface
        self.activation_status = :failed
        return
      end

      reported_status = activating_interface['ActiveStatus']

      if reported_status == 'active'
        self.activation_status = :started
      elsif reported_status == 'activating'
        if max_wait > 0
          self.activation_status = :starting
        else
          self.activation_status = :timed_out
        end
      else
        self.activation_status = :failed
      end
    end

  private

    def do_sleep(secs)
      # I'm calling Kernel.sleep directly so we can easily stub it out.
      ::Kernel.sleep secs
      self.min_wait -= secs
      self.max_wait -= secs
    end
  end
end

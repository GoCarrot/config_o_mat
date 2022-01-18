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
  class DetermineRunningInstance < LifecycleVM::OpBase
    reads :systemd_interface, :service
    writes :running_instance, :activating_instance

    RUNNING_STATES = %w[active activating reloading].freeze

    def call
      i1_running = RUNNING_STATES.include?(systemd_interface.unit_status("#{service}1"))
      i2_running = RUNNING_STATES.include?(systemd_interface.unit_status("#{service}2"))

      if i1_running && i2_running
        error :service, 'both instances are currently running!'
      elsif i1_running
        self.activating_instance = 2
        self.running_instance = 1
      elsif i2_running
        self.activating_instance = 1
        self.running_instance = 2
      else
        # If neither version is up, attempt to bring up instance 1. Our attempt to stop
        # instance 2 will be a noop.
        self.activating_instance = 1
        self.running_instance = 2
      end
    end
  end
end

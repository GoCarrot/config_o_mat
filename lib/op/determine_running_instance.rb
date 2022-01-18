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
      i1_name = "#{service}1"
      i1_status = systemd_interface.unit_status(i1_name)
      logger&.info(:service_status, name: i1_name, status: i1_status)

      i2_name = "#{service}2"
      i2_status = systemd_interface.unit_status(i2_name)
      logger&.info(:service_status, name: i2_name, status: i2_status)

      i1_running = RUNNING_STATES.include?(i1_status)
      i2_running = RUNNING_STATES.include?(i2_status)

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

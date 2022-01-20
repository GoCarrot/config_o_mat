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

require 'lifecycle_vm'

module ConfigOMat
  module FlipFlopper
    class Memory < LifecycleVM::Memory
      attr_reader :systemd_interface, :service, :runtime_directory
      attr_accessor :running_instance, :activating_instance, :activation_status, :activating_interface,
                    :min_wait, :max_wait

      def initialize(
        systemd_interface: nil,
        service: nil,
        min_wait: 5,
        max_wait: 30,
        runtime_directory: nil,
        running_instance: nil,
        activating_instance: nil,
        activation_status: nil,
        activating_interface: nil,
        logger: nil
      )
        @systemd_interface = systemd_interface
        @service = service
        @min_wait = min_wait
        @max_wait = max_wait
        @runtime_directory = runtime_directory
        @running_instance = running_instance
        @activating_instance = activating_instance
        @activation_status = activation_status
        @activating_interface = activating_interface
        @logger = logger
      end
    end
  end
end

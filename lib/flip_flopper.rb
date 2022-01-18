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
require 'flip_flop_memory'
require 'op'

class FlipFlopper < LifecycleVM::VM
  memory_class FlipFlopMemory

  on :start, do: Op::DetermineRunningInstance, then: :start_activating_instance
  on :start_activating_instance, do: Op::StartActivatingInstance, then: :wait_for_service_start
  on :wait_for_service_start, do: Op::CheckServiceStatus, then: {
    case: Cond::ServiceStatus,
    when: {
      starting: :wait_for_service_start,
      started: :stop_initial_service,
      failed: :fail,
      timed_out: :abort
    }
  }

  on :stop_initial_service, do: Op::StopInitialInstance, then: :exit
  on :fail, do: Op::ReportFailure, then: :exit

  on :abort, do: Op::StopActivatingInstance, then: :fail
end

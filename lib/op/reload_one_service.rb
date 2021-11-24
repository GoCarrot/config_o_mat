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
  class ReloadOneService < Lifecycle::OpBase
    reads :services_to_reload, :runtime_directory, :service_defs
    writes :services_to_reload

    def call
      service = services_to_reload.pop
      service_def = service_defs[service]
      unit = service_def.systemd_unit

      file_path = File.join(runtime_directory, unit + '.restart')

      logger&.notice(
        :service_restart,
        name: service, systemd_unit: unit, touched_path: file_path
      )

      FileUtils.touch(file_path)
    end
  end
end

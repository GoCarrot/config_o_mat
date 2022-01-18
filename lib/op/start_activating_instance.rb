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
  class StartActivatingInstance < LifecycleVM::OpBase
    reads :service, :activating_instance, :runtime_directory

    def call
      instance_name = "#{service}#{activating_instance}"
      file_path = File.join(runtime_directory,  "#{instance_name}.start")

      logger&.notice(:service_start, name: instance_name)

      FileUtils.touch(file_path)
    end
  end
end

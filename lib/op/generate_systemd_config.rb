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

require 'fileutils'

module Op
  class GenerateSystemdConfig < LifecycleVM::OpBase
    DROPIN_FILE_NAME = '99_teak_configurator.conf'

    reads :template_defs, :service_defs, :runtime_directory, :systemd_directory, :systemd_interface

    def call
      managed_units = []
      service_defs.each do |(_, service)|
        unit = service.systemd_unit
        managed_units << unit

        dropin = %([Service]\n)
        service.templates.each do |tmpl|
          template = template_defs[tmpl.to_sym]
          dropin += %(LoadCredential=#{template.dst}:#{File.join(runtime_directory, template.dst)}\n)
        end

        dropin_dir = File.join(systemd_directory, "#{unit}.service.d")

        FileUtils.mkdir_p(dropin_dir)
        File.open(File.join(dropin_dir, DROPIN_FILE_NAME), 'w') { |f| f.write(dropin) }
      end

      systemd_interface.enable_restart_paths(managed_units)
      systemd_interface.daemon_reload
    end
  end
end

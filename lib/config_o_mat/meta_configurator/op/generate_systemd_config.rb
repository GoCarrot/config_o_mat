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

module ConfigOMat
  module Op
    class GenerateSystemdConfig < LifecycleVM::OpBase
      DROPIN_FILE_NAME = '99_teak_configurator.conf'

      reads :template_defs, :service_defs, :runtime_directory, :systemd_directory, :systemd_interface

      def call
        grouped_restart_modes = service_defs.values.group_by(&:restart_mode)
        restarts = grouped_restart_modes.fetch(:restart, []) + grouped_restart_modes.fetch(:restart_all, [])
        flip_flops = grouped_restart_modes[:flip_flop]

        enable_restarts(restarts) if !restarts.empty?
        enable_flip_flops(flip_flops) if flip_flops

        systemd_interface.daemon_reload
      end

    private

      def write_dropin(unit, service)
        dropin = %([Service]\n)
        service.templates.each do |tmpl|
          template = template_defs[tmpl.to_sym]
          dropin += %(LoadCredential=#{template.dst}:#{File.join(runtime_directory, template.dst)}\n)
        end

        dropin_dir = File.join(systemd_directory, "#{unit}.service.d")

        FileUtils.mkdir_p(dropin_dir)
        File.open(File.join(dropin_dir, DROPIN_FILE_NAME), 'w') { |f| f.write(dropin) }
      end

      def enable_restarts(services)
        units = []
        services.each do |service|
          units << service.restart_unit

          write_dropin(service.systemd_unit, service)
        end

        systemd_interface.enable_restart_paths(units)
      end

      def enable_flip_flops(services)
        units = []
        services.each do |service|
          unit = service.systemd_unit
          units << "#{unit}1"
          units << "#{unit}2"

          write_dropin(unit, service)
        end

        systemd_interface.enable_start_stop_paths(units)
      end
    end
  end
end

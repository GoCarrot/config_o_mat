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

require 'config_o_mat/flip_flopper'

require 'dbus'

module ConfigOMat
  module Op
    class ReloadOneService < LifecycleVM::OpBase
      reads :services_to_reload, :runtime_directory, :service_defs, :systemd_interface
      writes :services_to_reload

      def call
        service = services_to_reload.pop
        service_def = service_defs[service]
        restart_mode = service_def.restart_mode

        if restart_mode == :restart || restart_mode == :restart_all
          do_restart(service, service_def)
        else
          do_flip_flop(service, service_def)
        end
      end

    private

      def do_restart(service, service_def)
        file_path = File.join(runtime_directory, service_def.restart_unit + '.restart')

        logger&.notice(
          :service_restart,
          name: service, systemd_unit: service_def.systemd_unit, touched_path: file_path
        )

        FileUtils.touch(file_path)
      end

      def do_flip_flop(service, service_def)
        mem = ConfigOMat::FlipFlopper::Memory.new(
          runtime_directory: runtime_directory,
          service: service_def.systemd_unit,
          systemd_interface: systemd_interface,
          logger: logger
        )
        vm = ConfigOMat::FlipFlopper::VM.new(mem)
        vm.call

        if vm.errors?
          vm.errors.each do |(key, value)|
            value.each { |v| error key, v }
          end
        end
      end
    end
  end
end

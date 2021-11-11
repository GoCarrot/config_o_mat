# frozen_string_literal: true

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

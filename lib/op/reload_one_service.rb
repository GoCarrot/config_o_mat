# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class ReloadOneService < Lifecycle::OpBase
    reads :services_to_reload, :runtime_directory, :service_defs
    writes :services_to_reload

    def call
      service = services_to_reload.pop
      service_def = service_defs[service]
      FileUtils.touch(File.join(runtime_directory, service_def.systemd_unit + '.restart'))
    end
  end
end

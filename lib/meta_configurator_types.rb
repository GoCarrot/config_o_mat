# frozen_string_literal: true

class SystemdInterface
  def enable_restart_path(units)
    units.each do |unit|
      `systemctl enable teak-configurator-restart-service@#{unit}.path`
    end
  end

  def daemon_reload
    `systemctl daemon-reload`
  end
end

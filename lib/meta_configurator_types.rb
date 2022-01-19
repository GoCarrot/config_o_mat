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

require 'dbus'

class SystemdInterface
  SERVICE_NAME = 'org.freedesktop.systemd1'
  OBJECT_PATH = '/org/freedesktop/systemd1'
  MANAGER_INTERFACE = 'org.freedesktop.systemd1.Manager'

  UNIT_INTERFACE = 'org.freedesktop.systemd1.Unit'
  UNIT_STATE = 'ActiveState'

  def initialize(sysbus = nil)
    if sysbus
      @sysd_service = sysbus[SERVICE_NAME]
      obj = @sysd_service[OBJECT_PATH]
      @sysd_iface = obj[MANAGER_INTERFACE]
    end
  end

  def service_interface(unit_name)
    unit_path = @sysd_iface.GetUnit("#{unit_name}.service")
    unit_obj = @sysd_service[unit_path]
    unit_obj[UNIT_INTERFACE]
  rescue DBus::Error
    nil
  end

  def service_status(unit_name)
    iface = service_interface(unit_name)
    if iface
      iface[UNIT_STATE]
    else
      'inactive'
    end
  end

  def enable_restart_paths(units)
    path_units = units.map { |unit| "teak-configurator-restart-service@#{unit}.path" }
    enable_and_start(path_units)
  end

  def enable_start_stop_paths(units)
    path_units = units.flat_map do |unit|
      ["teak-configurator-start-service@#{unit}.path", "teak-configurator-stop-service@#{unit}.path"]
    end
    enable_and_start(path_units)
  end

  def daemon_reload
    @sysd_iface.Reload()
  end

  def ==(other)
    eql?(other)
  end

  def eql?(other)
    return false if !other.is_a?(self.class)
    return false if other.instance_variable_get(:@sysd_service) != @sysd_service
    true
  end

private

  def enable_and_start(units)
    @sysd_iface.EnableUnitFiles(
      units,
      true, # Runtime
      false # force
    )
    daemon_reload
    units.each do |unit|
      @sysd_iface.StartUnit(unit, 'replace')
    end
  end
end

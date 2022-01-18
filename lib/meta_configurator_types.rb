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
  BUS_NAME = 'org.freedesktop.systemd1'
  OBJECT_PATH = '/org/freedesktop/systemd1'
  UNIT_INTERFACE = 'org.freedesktop.systemd1.Unit'
  UNIT_STATE = 'ActiveState'

  def initialize(sysbus = nil)
    if sysbus
      @sysd_service = sysbus[BUS_NAME]
      @sysd_iface = @sysd_service[OBJECT_PATH]
    end
  end

  def unit_interface(unit_name)
    unit_path = @sysd_iface.GetUnit(unit_name)
    unit_obj = @sysd_service[unit_path]
    unit_obj[UNIT_INTERFACE]
  rescue DBus::Error
    nil
  end

  def unit_status(unit_name)
    unit_interface(unit_name).try { |iface| iface[UNIT_STATE] } || 'inactive'
  end

  def enable_restart_paths(units)
    units.each do |unit|
      `systemctl enable --now --runtime teak-configurator-restart-service@#{unit}.path`
    end
  end

  def enable_start_stop_paths(units)
    units.each do |unit|
      `systemctl enable --now --runtime teak-configurator-start-service@#{unit}.path teak-configurator-stop-service@#{unit}.path`
    end
  end

  def daemon_reload
    `systemctl daemon-reload`
  end
end

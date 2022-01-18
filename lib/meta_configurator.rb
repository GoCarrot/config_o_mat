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

require 'lifecycle_vm'

require 'meta_configurator_memory'

require 'op/parse_meta_cli'
require 'cond/early_exit'
require 'op/load_meta_config'
require 'op/generate_systemd_config'

class MetaConfigurator < LifecycleVM::VM
  VERSION = "0.0.1"

  memory_class MetaConfiguratorMemory

  on :start, do: Op::ParseMetaCli, then: {
    case: Cond::EarlyExit,
    when: {
      true => :exit,
      false => :reading_meta_config
    }
  }

  on :reading_meta_config, do: Op::LoadMetaConfig, then: :generating_systemd_config

  on :generating_systemd_config, do: Op::GenerateSystemdConfig, then: :exit
end

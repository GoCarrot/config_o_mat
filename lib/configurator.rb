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
require 'op'
require 'cond'
require 'configurator_memory'

class Configurator < LifecycleVM::VM
  VERSION = "0.0.1"

  memory_class ConfiguratorMemory
  on_op_failure :op_failure
  terminal :fail

  on :start, do: Op::ParseCli, then: {
    case: Cond::EarlyExit,
    when: {
      true => :exit,
      false => :reading_meta_config
    }
  }

  on :reading_meta_config, do: Op::LoadMetaConfig, then: :compiling_templates

  on :compiling_templates, do: Op::CompileTemplates, then: :connecting_to_appconfig

  on :connecting_to_appconfig, do: Op::ConnectToAppconfig, then: :refreshing_profiles

  on :refreshing_profiles,
     do: Op::RefreshAllProfiles,
     then: {
       case: Cond::FirstRun,
       when: {
         true => :initial_applying_profiles,
         false => :applying_profiles
       }
     }

  on :initial_applying_profiles, do: Op::ApplyAllProfiles, then: :generating_templates

  on :applying_profiles,
     then: {
       case: Cond::ProfilesToApply,
       when: {
         true => :applying_profile,
         false => :running
       }
     }

  on :applying_profile, do: Op::StageOneProfile, then: :generating_templates

  on :generating_templates, do: Op::GenerateAllTemplates, then: {
    case: Cond::FirstRun,
    when: {
      true => :notifying_systemd,
      false => :reloading_services
    }
  }

  on :notifying_systemd, do: Op::NotifySystemdStart, then: :running

  on :reloading_services,
     then: {
       case: Cond::ServicesToReload,
       when: {
         true => :reloading_service,
         false => { do: Op::CommitStagedProfile, then: :applying_profiles }
       }
     }

  on :reloading_service, do: Op::ReloadOneService, then: :reloading_services

  on :running,
     do: Op::NextTick,
     then: {
       case: Cond::NextState,
       when: {
         refreshing_profiles: :refreshing_profiles,
         graceful_shutdown: :exit,
         fail: :fail,
         running: :running
       }
     }

  on :op_failure,
     then: {
       case: Cond::FirstRun,
       when: {
         true => :fail,
         false => {
           case: Cond::RetriesLeft,
           when: {
             true => { do: Op::WaitRetry, then: :refreshing_profile },
             false => :fail
           }
         }
       }
     }

  on :refreshing_profile, do: Op::RefreshProfile, then: :applying_profile
end

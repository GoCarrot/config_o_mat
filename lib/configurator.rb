# frozen_string_literal: true

require 'lifecycle'
require 'op'
require 'cond'
require 'configurator_memory'

class Configurator < Lifecycle::VM
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

  on :generating_templates, do: Op::GenerateAllTemplates, then: :reloading_services

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

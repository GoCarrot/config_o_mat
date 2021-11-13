# frozen_string_literal: true

require 'lifecycle'

require 'meta_configurator_memory'

require 'op/parse_meta_cli'
require 'cond/early_exit'
require 'op/load_meta_config'
require 'op/generate_systemd_config'

class MetaConfigurator < Lifecycle::VM
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

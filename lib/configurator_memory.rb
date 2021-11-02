# frozen_string_literal: true

require 'lifecycle/vm_memory'

class ConfiguratorMemory < Lifecycle::VmMemory
  attr_accessor :argv, :env, :early_exit, :configuration_directory,
                :runtime_directory, :run_count, :profile_defs, :template_defs,
                :service_defs, :dependencies, :refresh_interval

  def initialize(
    argv: [],
    env: {},
    early_exit: false,
    configuration_directory: nil,
    runtime_directory: nil,
    run_count: 0,
    profile_defs: {},
    template_defs: {},
    service_defs: {},
    dependencies: {},
    refresh_interval: 5
  )
    super()

    @argv = argv
    @env = env
    @early_exit = early_exit
    @configuration_directory = configuration_directory
    @runtime_directory = runtime_directory
    @run_count = run_count
    @profile_defs = profile_defs
    @template_defs = template_defs
    @service_defs = service_defs
    @dependencies = dependencies
    @refresh_interval = refresh_interval
  end
end

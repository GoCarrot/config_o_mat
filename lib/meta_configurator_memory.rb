# frozen_string_literal: true

require 'lifecycle/vm_memory'

class MetaConfiguratorMemory < Lifecycle::VmMemory
  attr_accessor :argv, :env, :early_exit, :configuration_directory, :runtime_directory,
                :systemd_directory, :logs_directory, :profile_defs,
                :template_defs, :service_defs, :dependencies, :refresh_interval,
                :client_id, :retry_count, :retries_left, :retry_wait,
                :region

  def initialize(
    argv: [],
    env: {},
    early_exit: false,
    configuration_directory: nil,
    runtime_directory: nil,
    logs_directory: nil,
    systemd_directory: nil,
    profile_defs: {},
    template_defs: {},
    service_defs: {},
    dependencies: {},
    refresh_interval: 5,
    client_id: '',
    logger: nil,
    retry_count: 3,
    retries_left: 3,
    retry_wait: 2,
    region: nil
  )
    super()

    @argv = argv
    @env = env
    @early_exit = early_exit
    @configuration_directory = configuration_directory
    @runtime_directory = runtime_directory
    @logs_directory = logs_directory
    @systemd_directory = systemd_directory
    @profile_defs = profile_defs
    @template_defs = template_defs
    @service_defs = service_defs
    @dependencies = dependencies
    @refresh_interval = refresh_interval
    @client_id = client_id
    @logger = logger
    @retry_count = retry_count
    @retries_left = retries_left
    @retry_wait = retry_wait
    @region = region
  end
end

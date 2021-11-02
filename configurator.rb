$LOAD_PATH << File.join(__dir__, 'lib')

require_relative 'lib/configurator'
require_relative 'lib/configurator_memory'

memory = ConfiguratorMemory.new(argv: ARGV, env: ENV)
vm = Configurator.new(memory)
vm.call

if vm.errors?
  warn "Errored executing #{vm.error_op.class.name}"
  warn "Errors: #{vm.errors}"

  if vm.recovery_errors?
    warn ''
    warn "Errors recovering from error. Errored executing recovery #{vm.current_op.class.name}"
    warn "Errors: #{vm.recovery_errors}"
  end

  exit 1
end

# frozen_string_literal: true

module Lifecycle
  class VmMemory
    BUILTINS = %i[current_state last_state current_op error_op].freeze

    attr_accessor(*BUILTINS)
    attr_accessor :logger
  end
end

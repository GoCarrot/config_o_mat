# frozen_string_literal: true

module Lifecycle
  class VmMemory
    BUILTINS = %i[current_state last_state current_op error_op logger].freeze

    attr_accessor(*BUILTINS)
  end
end

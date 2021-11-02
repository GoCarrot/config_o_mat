# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class WaitRetry < Lifecycle::OpBase
    def call
      error :base, "not implemented"
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class StageOneProfile < Lifecycle::OpBase
    reads :profiles_to_apply
    writes :applying_profile

    def call
      self.applying_profile = profiles_to_apply.pop
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class StageOneProfile < Lifecycle::OpBase
    reads :profiles_to_apply
    writes :applying_profile, :profiles_to_apply

    def call
      self.applying_profile = profiles_to_apply.pop

      error applying_profile.name, applying_profile.errors if applying_profile.errors?
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class StageOneProfile < Lifecycle::OpBase
    reads :profiles_to_apply
    writes :applying_profile, :profiles_to_apply

    def call
      self.applying_profile = profiles_to_apply.pop

      # We defer error checking to GenerateAllTemplates so that even if errored the profile gets set as
      # the applying_profile, which simplifies retry logic.
    end
  end
end

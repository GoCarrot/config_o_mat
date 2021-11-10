# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class CommitStagedProfile < Lifecycle::OpBase
    reads :applied_profiles, :applying_profile
    writes :applied_profiles, :applying_profile

    def call
      applied_profiles[applying_profile.name] = applying_profile
      self.applying_profile = nil
    end
  end
end

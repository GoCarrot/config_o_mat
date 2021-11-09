# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class CommitStagedProfile < Lifecycle::OpBase
    reads :applied_profiles, :profiles_to_apply, :applying_profile
    writes :applied_profiles, :profiles_to_apply, :applying_profile

    def call
      prof_name = applying_profile.name

      self.profiles_to_apply = profiles_to_apply.reject { |prof| prof.name == prof_name }
      applied_profiles[prof_name] = applying_profile
      self.applying_profile = nil
    end
  end
end

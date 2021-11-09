# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class ApplyAllProfiles < Lifecycle::OpBase
    reads :profiles_to_apply, :applied_profiles
    writes :profiles_to_apply, :applied_profiles

    def call
      profiles_to_apply.each do |profile|
        applied_profiles[profile.name] = profile
      end

      self.profiles_to_apply = []
    end
  end
end

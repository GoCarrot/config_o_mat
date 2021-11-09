# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class ProfilesToApply < Lifecycle::CondBase
    reads :profiles_to_apply

    def call
      !profiles_to_apply.empty?
    end
  end
end

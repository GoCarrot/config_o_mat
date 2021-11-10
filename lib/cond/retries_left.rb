# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class RetriesLeft < Lifecycle::CondBase
    reads :error_op, :retries_left, :applying_profile

    def call
      logger&.error(:op_failure, op: error_op.class.name, errors: error_op.errors)

      # If we aren't currently applying a profile then there's nothing for us to retry.
      return false if applying_profile.nil?

      # If we're out of retries, well, no more retrying
      return false if retries_left.zero?

      true
    end
  end
end

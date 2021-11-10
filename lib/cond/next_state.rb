# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class NextState < Lifecycle::CondBase
    reads :next_state

    def call
      next_state
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class FirstRun < Lifecycle::CondBase
    reads :run_count

    def call
      run_count.zero?
    end
  end
end

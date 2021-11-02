# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class NextState < Lifecycle::CondBase
    reads :run_count
    writes :run_count

    def call
      self.run_count += 1
    end
  end
end

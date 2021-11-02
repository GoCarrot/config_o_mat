# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class RetriesLeft < Lifecycle::CondBase
    def call
      true
    end
  end
end

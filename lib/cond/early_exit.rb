# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class EarlyExit < Lifecycle::CondBase
    reads :early_exit

    def call
      early_exit
    end
  end
end

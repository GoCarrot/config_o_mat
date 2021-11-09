# frozen_string_literal: true

require 'lifecycle/cond_base'

module Cond
  class ServicesToReload < Lifecycle::CondBase
    reads :services_to_reload

    def call
      !services_to_reload.empty?
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/op_base'

require 'sd_notify'

module Op
  class NotifySystemdStart < Lifecycle::OpBase
    def call
      SdNotify.ready
    end
  end
end

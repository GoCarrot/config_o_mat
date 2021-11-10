# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class WaitRetry < Lifecycle::OpBase
    reads :retry_wait, :retry_count, :retries_left
    writes :retries_left

    def call
      # Exponential backoff
      wait = retry_wait * (2**(retry_count - retries_left))

      # With jitter
      wait += rand(retry_wait + 1) - (retry_wait / 2.0)

      logger&.notice(:retry_wait, wait: wait)

      # Calling Kernel.sleep directly for easy test stubbing
      Kernel.sleep wait

      self.retries_left -= 1
    end
  end
end

# frozen_string_literal: true

require 'lifecycle/op_base'

module Op
  class NextTick < Lifecycle::OpBase
    PAUSE_INTERVAL = 1

    reads :last_refresh_time, :refresh_interval, :run_count, :retry_count
    writes :next_state, :run_count, :retries_left

    def call
      self.run_count += 1

      # If we got here then our retry process has succeeded.
      self.retries_left = retry_count

      # I'm calling Kernel.sleep directly so that tests can easily stub it out.
      Kernel.sleep PAUSE_INTERVAL

      if Time.now.to_i - last_refresh_time > refresh_interval
        self.next_state = :refreshing_profiles
      else
        self.next_state = :running
      end
    end
  end
end

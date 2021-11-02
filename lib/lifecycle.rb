# frozen_string_literal: true

module Lifecycle
  # Base class for all errors raised by Lifecycle.
  class Error < RuntimeError; end
end

require 'lifecycle/vm'
require 'lifecycle/then'
require 'lifecycle/state'

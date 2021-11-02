# frozen_string_literal: true

require 'lifecycle/then'

module Lifecycle
  # Represents a state in the lifecycle.
  # A state may optionally define a single operation to perform, and then must
  # define which state to transition to next.
  # Transitions may be conditional, controlled by a subclass of Lifecycle::CondBase
  # @see Lifecycle::VM
  # @see Lifecycle::OpBase
  # @see Lifecycle::CondBase
  class State
    attr_reader :name, :op, :then

    def initialize(name, options)
      @name = name
      @op = options[:do]
      @then = Then.new(options[:then]) if options.key?(:then)
    end
  end
end

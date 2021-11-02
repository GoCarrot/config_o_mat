# frozen_string_literal: true

require 'lifecycle/vm'

module Lifecycle
  class Then
    class Simple
      def initialize(state)
        @state = state
      end

      def call(_vm)
        @state
      end
    end

    class AnonymousState
      attr_reader :op, :then

      def initialize(options)
        @op = options[:do]
        @then = Then.new(options[:then])
      end

      def call(vm)
        vm.do_anonymous_state(self)
      end
    end

    def self.new(options)
      if options.kind_of?(Symbol)
        return Simple.new(options)
      else
        super
      end
    end

    def initialize(options)
      @cond = options[:case]
      @branches = options[:when].transform_values do |value|
        if value.kind_of?(Hash)
          if value.key?(:case)
            Then.new(value)
          elsif value.key?(:then)
            AnonymousState.new(value)
          else
            value
          end
        elsif value.kind_of?(Symbol)
          Simple.new(value)
        else
          value
        end
      end
    end

    class InvalidCond < ::Lifecycle::Error
      attr_reader :value, :cond, :branches, :vm

      def initialize(value, cond, branches, vm)
        @value = value
        @cond = cond
        @branches = branches
        @vm = vm

        super("Unhandled condition result #{value.inspect} returned by #{cond} in #{branches}. Current context #{@vm}")
      end
    end

    def call(vm)
      value = @cond.call(vm.memory)
      branch = @branches[value]
      raise InvalidCond.new(value, @cond, @branches, vm) unless branch.respond_to?(:call)

      branch.call(vm)
    end
  end
end

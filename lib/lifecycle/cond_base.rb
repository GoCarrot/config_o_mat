# frozen_string_literal: true

module Lifecycle
  class CondBase
    class InvalidAttr < RuntimeError
      attr_reader :cond_class, :attribute

      def initialize(cond_class, attribute)
        @cond_class = cond_class
        @attribute = attribute
        super("Invalid attribute #{attribute} access by #{cond_class.name}")
      end
    end

    def self.reads(*attrs)
      @reads ||= {}
      @reads.merge!(Hash[attrs.map { |attribute| [attribute, :"@#{attribute}"] }])
      attr_reader(*attrs)
    end

    def self.call(state)
      obj = allocate

      @reads&.each do |(attribute, ivar)|
        raise InvalidAttr.new(self, attribute) unless state.respond_to?(attribute)

        obj.instance_variable_set(ivar, state.send(attribute).clone)
      end

      obj.send(:initialize, state.logger)
      obj.send(:call)
    end

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def call; end
  end
end

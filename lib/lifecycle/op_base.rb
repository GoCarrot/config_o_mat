# frozen_string_literal: true

require 'lifecycle/vm_memory'

module Lifecycle
  class OpBase
    class InvalidAttr < RuntimeError
      attr_reader :op_class, :attribute

      def initialize(op_class, attribute)
        @op_class = op_class
        @attribute = attribute
        super("Invalid attribute #{attribute} access by #{op_class.name}")
      end
    end

    def self.reads(*attrs)
      @reads ||= {}
      attr_reader(*attrs)

      @reads.merge!(Hash[attrs.map { |attribute| [attribute, :"@#{attribute}"] }])
      @reads
    end

    def self.writes(*attrs)
      @writes ||= {}

      attrs.each do |attribute|
        attribute = attribute.to_sym
        raise InvalidAttr.new(self, attribute) if Lifecycle::VmMemory::BUILTINS.include?(attribute)

        attr_accessor attribute

        @writes[attribute] = :"#{attribute}="
      end

      @writes
    end

    def self.call(state)
      obj = allocate

      @reads&.each do |(attribute, ivar)|
        raise InvalidAttr.new(self, attribute) unless state.respond_to?(attribute)

        obj.instance_variable_set(ivar, state.send(attribute).clone)
      end

      obj.send(:initialize)
      obj.send(:call)
      obj.send(:validate)

      unless obj.errors?
        @writes&.each do |(attribute, setter)|
          raise InvalidAttr.new(self, attribute) unless state.respond_to?(setter)

          state.send(setter, obj.send(attribute))
        end
      end

      obj
    end

    def initialize
      @errors = nil
    end

    def call; end
    def validate; end

    attr_reader :errors

    def error(field, message)
      @errors ||= {}
      @errors[field] ||= []
      @errors[field] << message
    end

    def errors?
      !(@errors.nil? || @errors.empty?)
    end
  end
end

# frozen_string_literal: true

require 'forwardable'

require 'lifecycle/state'
require 'lifecycle/vm_memory'

module Lifecycle
  class VM
    extend Forwardable

    # By default the lifecycle state machine starts at :start, ends at :exit,
    # and immediately termiantes on op failure.
    DEFAULT_START = :start
    DEFAULT_TERMINALS = [:exit].freeze
    DEFAULT_ON_OP_FAILURE = :exit

    # Stores state machine configuration.
    class Config
      # @return [Symbol, nil] the state to transition to when an op fails
      attr_accessor :on_op_failure

      # @return [Hash<Symbol, Lifecycle::State>] a mapping of state names to state structures
      attr_accessor :states

      # @return [Symbol] the state to start at
      attr_accessor :initial_state

      # @return [Array<Symbol>] a list of state names which the machine will stop at
      attr_accessor :terminal_states

      # @return [Lifecycle::VmMemory] not an instance of but the class of the memory for this
      #   particular machine
      attr_accessor :memory_class

      # @return [Hash<Symbol, Symbol>] keys are values this machine will read on #call, values
      #   are ivar forms of the keys
      attr_accessor :reads

      # @return [Hash<Symbol, Symbol>] keys are the values this machine will write on #call,
      #   values are setter forms of the keys
      attr_accessor :writes

      # Creates a new Config with default settings
      def initialize
        @states = {}
        @on_op_failure = DEFAULT_ON_OP_FAILURE
        @initial_state = DEFAULT_START
        @terminal_states = DEFAULT_TERMINALS
        @memory_class = Lifecycle::VmMemory
        @reads = {}
        @writes = {}
        @terminal_states.each do |state|
          @states[state] ||= State.new(state, {})
        end
      end
    end

    # Error raised if the machine attempts to enter a state not declared with .on
    class InvalidState < ::Lifecycle::Error
      # @return [Symbol] the name of the state that was attempted
      attr_reader :state

      # @return [Lifecycle::VM] the state machine being executed
      attr_reader :vm

      # @param state [Symbol] the name of the state that does not exist
      # @param vm [Lifecycle::VM] the vm raising the error
      def initialize(state, vm)
        @state = state
        @vm = vm
        super("Invalid state transition to #{@state}. Current context #{@vm}")
      end
    end

    class << self
      # Set the state to transition to if an op fails
      # @param state [Symbol] the state to transition to when any op fails.
      #   There may only be one declared failure handler for any VM.
      def on_op_failure(state)
        @config ||= Config.new
        @config.on_op_failure = state
      end

      # Declare a state with an optional op and conditional transitions
      # @param state [Symbol] the name of the state
      # @param opts [Hash]
      # @option opts [Lifecycle::OpBase] :do (nil) the op to execute upon entering this state
      # @option opts [Symbol, Hash] :then (nil) either the name of the state to transition do
      #   after executing :do, or a hash of the form
      #   { case: Lifecycle::CondBase, when: Hash<_, [Symbol, Hash]> }
      def on(state, opts)
        @config ||= Config.new
        @config.states[state] = State.new(state, opts)
      end

      # Set the state to start execution at
      def initial(state)
        @config ||= Config.new
        @config.initial_state = state
      end

      # Set one or more states as states to halt execution at
      def terminal(*states)
        @config ||= Config.new
        @config.terminal_states = DEFAULT_TERMINALS if states.length.zero?
        @config.terminal_states += states
        states.each do |state|
          @config.states[state] ||= State.new(state, {})
        end
      end

      # Set the class to be instantiated to store VM memory
      def memory_class(klass)
        @config ||= Config.new
        @config.memory_class = klass
      end

      # Specifies the slots to read from source memory when this machine is executed as
      # part of another machine.
      # @param attrs [Array<Symbol>] the list of slots to read from source memory
      # @return [void]
      def reads(*attrs)
        @config ||= Config.new
        @config.reads.merge!(Hash[attrs.map { |attribute| [attribute, :"@#{attribute}"] }])
      end

      # Specifies the slots to write back to source memory when this machine is executed as
      # part of another machine.
      # @param attrs [Array<Symbol>] the list of slots to write back to source memory
      # @return [void]
      def writes(*attrs)
        @config ||= Config.new
        attrs.each do |attribute|
          attribute = attribute.to_sym
          raise InvalidAttr.new(self, attribute) if Lifecycle::VmMemory::BUILTINS.include?(attribute)
          @config.writes[attribute] = :"#{attribute}="
        end
      end

      # @return [Config] the machine configuration
      attr_reader :config
    end

    # The current VM memory
    # @return [Lifecycle::VmMemory] the current VM memory
    attr_reader :memory

    # (see Lifecycle::VM.config)
    def config
      self.class.config
    end

    def_delegators :@memory, *Lifecycle::VmMemory::BUILTINS
    def_delegators :@memory, *Lifecycle::VmMemory::BUILTINS.map { |field| :"#{field}=" }

    def initialize(memory = nil)
      @memory = memory || @config.memory_class.new
    end

    # Executes the VM until a terminal state is reached.
    # @note May never terminate!
    def call
      next_state = config.initial_state
      loop do
        next_state = do_state(next_state)
        break unless next_state
      end
      self
    end

    # Did this vm exit with an errored op?
    # @return [Boolean] true if the vm exited with an errored op
    def errors?
      !!error_op&.errors?
    end

    # @return [Hash<Symbol, Array<String>>] errors from the errored op
    def errors
      error_op&.errors
    end

    # Did this vm encounter an error trying to recover from an errored op?
    # @return [Boolean] true if an op associated with the op failure state errored
    def recovery_errors?
      !!current_op&.errors?
    end

    # @return [Hash<Symbol, Array<String>>] errors from the op failure op
    def recovery_errors
      current_op&.errors
    end

    # Executes a VM from an optional starting state.
    #
    # Any values declared with .reads will be read out of state, and any values
    # declared with .writes will be written back into state if the vm executes
    # successfully.
    #
    # Internally, the VM will assign reads to its memory in slots of the same name,
    # and will copy writes out if slots in its memory of the same name.
    #
    # @param state [Object, nil] state to be read/written by VM execution
    def self.call(state = nil)
      obj = config.memory_class.new

      config.reads.each do |(attribute, ivar)|
        raise InvalidAttr.new(self, attribute) unless state.respond_to?(attribute)

        obj.instance_variable_set(ivar, state.send(attribute).clone)
      end

      vm = new(obj).call

      unless vm.errors?
        config.writes.each do |(attribute, setter)|
          raise InvalidAttr.new(self, attribute) unless state.respond_to?(setter)

          state.send(setter, obj.send(attribute))
        end
      end

      vm
    end

    # @private
    def do_anonymous_state(state)
      raise InvalidState.new(state, self) if state.op && current_op

      do_op(state)
    end

  private

    def do_state(next_state)
      logger&.debug(:enter, state: state, ctx: self)
      self.last_state = current_state

      state = config.states[next_state]
      raise InvalidState.new(next_state, self) unless state

      self.current_state = state

      return nil if config.terminal_states.include?(current_state.name)

      do_op(state)
    end

    def do_op(state)
      self.current_op = state.op&.call(memory)

      if current_op&.errors?
        logger&.error(:op_errors, op_class: state.op.name, errors: current_op.errors, ctx: self)
        on_op_failure = config.on_op_failure

        # If we're here, then first an op failed, and then an op executed by our
        # on_op_failure state also failed. In this case, both error_op and
        # current_op should be set, and both should #errors? => true
        return DEFAULT_TERMINALS.first if current_state.name == on_op_failure

        self.error_op = current_op

        # We unset current op here so that if there is no failure handler and we're
        # directly transitioning to a terminal state we do not indicate that there
        # were recovery errors (as there was no recovery)
        self.current_op = nil

        return on_op_failure
      # Only clear our error op if we have successfully executed another op
      elsif current_op
        self.error_op = nil
      end

      state.then.call(self)
    end
  end
end

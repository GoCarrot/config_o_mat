# frozen_string_literal: true

require 'lifecycle/op_base'

require 'yaml'

module Op
  class LoadMetaConfig < Lifecycle::OpBase
    module DeepMerge
      refine Hash do
        def deep_merge(other)
          dup.deep_merge!(other)
        end

        def deep_merge!(other)
          merge!(other) do |key, this_val, other_val|
            if this_val.respond_to?(:deep_merge!) &&
               other_val.respond_to?(:deep_merge!) &&
               this_val.is_a?(other_val.class)
              this_val.deep_merge(other_val)
            else
              other_val
            end
          end
        end
      end

      refine Array do
        def deep_merge(other)
          dup.deep_merge!(other)
        end

        def deep_merge!(other)
          concat(other) if other
        end
      end
    end

    using DeepMerge

    class ValidationError < RuntimeError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.to_s)
      end
    end

    class ConfigItem
      attr_reader :errors

      def errors?
        instance_variable_defined?(:@errors) && !(@errors.nil? || @errors.empty?)
      end

      def error(field, message)
        @errors ||= {}
        @errors[field] ||= []
        @errors[field] << message
      end

      def validate!
        validate
        raise ValidationError.new(errors) if errors?
      end

      def eql?(other)
        return false if !other.is_a?(self.class)
        true
      end

      alias == eql?
    end

    class Service < ConfigItem
      RESTART_MODES = %i[restart flip_flop].freeze

      attr_reader :systemd_unit, :restart_mode, :templates

      def initialize(opts)
        @systemd_unit = opts[:systemd_unit]
        @restart_mode = opts[:restart_mode]&.to_sym
        @templates = opts[:templates]
      end

      def validate
        error :templates, 'must be present' if @templates.nil? || @templates.empty?
        unless @templates.is_a?(Array) && @templates.all? { |v| v.is_a?(String) }
          error :templates, 'must be an array of strings'
        end
        error :systemd_unit, 'systemd_unit must be present' if @systemd_unit.nil? || @systemd_unit.empty?
        error :restart_mode, "restart mode must be one of #{RESTART_MODES}" unless RESTART_MODES.include?(@restart_mode)
      end

      def hash
        systemd_unit.hash ^ restart_mode.hash ^ templates.hash
      end

      def eql?(other)
        return false if !super(other)
        return false if other.systemd_unit != systemd_unit || other.restart_mode != restart_mode || other.templates != templates
        true
      end
    end

    class Template < ConfigItem
      attr_reader :src, :dst

      def initialize(opts)
        @src = opts[:src]
        @dst = opts[:dst]
      end

      def validate
        error :src, 'must be present' if @src.nil? || @src.empty?
        error :dst, 'must be present' if @dst.nil? || @dst.empty?
      end

      def hash
        src.hash ^ dst.hash
      end

      def eql?(other)
        return false if !super(other)
        return false if other.src != src || other.dst != dst
        true
      end
    end

    class Profile < ConfigItem
      attr_reader :application, :environment, :profile

      def initialize(opts)
        @application = opts[:application]
        @environment = opts[:environment]
        @profile = opts[:profile]
      end

      def validate
        error :application, 'must be present' if @application.nil? || @application.empty?
        error :environment, 'must be present' if @environment.nil? || @environment.empty?
        error :profile, 'must be present' if @profile.nil? || @profile.empty?
      end

      def hash
        application.hash ^ environment.hash ^ profile.hash
      end

      def eql?(other)
        return false if !super(other)
        return false if other.application != application || other.environment != environment || other.profile != profile
        true
      end
    end

    reads :configuration_directory
    writes :profile_defs, :template_defs, :service_defs, :dependencies,
           :refresh_interval, :logger

    def call
      # TODO: I would like to make this configurable. I think the trick
      # Sequel uses for its model classes (< Sequel::Model(source_dataset))
      # might be appropriate for how this system works?
      # do: Op::LoadMetaConfig(parser: Yaml.method(&:safe_load))
      parser = YAML.method(:safe_load)
      file_ending = '.conf'

      files =
        Dir.children(configuration_directory)
           .lazy
           .select { |f| f.end_with?(file_ending) }
           .map { |f| File.join(configuration_directory, f) }
           .select { |f| File.file?(f) }
           .to_a
           .sort!

      loaded_files =
        files.each_with_object({}) do |file, hash|
          hash[file] = parser.call(File.read(file), symbolize_names: true)
        rescue StandardError => e
          error file, e
        end

      # If we couldn't load a configuration file then it's probably not worth
      # exploding on any objects we fail to initialize -- that's an obvious
      # consequence and the additional noise might mask the root cause.
      return if errors?

      merged_config =
        loaded_files.each_with_object({}) do |(_filename, config), memo|
          memo.deep_merge!(config)
        end

      instantiate = proc do |key, klass|
        merged_config[key].each_with_object({}) do |(name, obj), defs|
          definition = klass.new(obj)
          definition.validate!
          defs[name] = definition
        rescue StandardError => e
          error key, { name => e }
        end
      end

      self.service_defs = instantiate.call(:services, Service)
      self.template_defs = instantiate.call(:templates, Template)
      self.profile_defs = instantiate.call(:profiles, Profile)

      # If we couldn't initialize everything then it's probably not worth exploding
      # on any missing dependencies -- that's an obvious consquence, and the addiitional
      # noise might mask the root cause.
      return if errors?

      self.dependencies = service_defs.each_with_object({}) do |(name, service), template_to_services|
        service.templates.each do |template|
          template = template&.to_sym
          if !template_defs.key?(template)
            error 'services', { name => "references undefined template #{template}" }
          else
            # Listing the same template multiple times is acceptable. Since we allow
            # merging config files, and this deep merges the service dependency list,
            # it's quite possible that a service could inadvertently declare the same
            # dependency twice in a way that's not easy to untangle.
            template_to_services[template] ||= Set.new
            template_to_services[template] << service
          end
        end
      end
    end
  end
end

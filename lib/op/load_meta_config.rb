# frozen_string_literal: true

require 'bundler/setup'

require 'lifecycle/op_base'
require 'configurator_types'

require 'logsformyfamily'

require 'securerandom'
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
            if this_val.respond_to?(:deep_merge) &&
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
          concat(other)
        end
      end
    end

    using DeepMerge

    LOG_TYPES = %i[stdout file].freeze

    reads :configuration_directory, :logs_directory, :env
    writes :profile_defs, :template_defs, :service_defs, :dependencies,
           :refresh_interval, :client_id, :logger

    def call
      default_config = {
        refresh_interval: 5,
        client_id: env.fetch('INVOCATION_ID') { SecureRandom.uuid }
      }

      # TODO: I would like to make this configurable. I think the trick
      # Sequel uses for its model classes (< Sequel::Model(source_dataset))
      # might be appropriate for how this system works?
      # do: Op::LoadMetaConfig(parser: Yaml.method(&:safe_load))
      parser = proc { |file| YAML.safe_load(file, symbolize_names: true) }
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
          hash[file] = parser.call(File.read(file))
        rescue StandardError => e
          error file, e
        end

      # If we couldn't load a configuration file then it's probably not worth
      # exploding on any objects we fail to initialize -- that's an obvious
      # consequence and the additional noise might mask the root cause.
      return if errors?

      merged_config =
        loaded_files.each_with_object(default_config) do |(_filename, config), memo|
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

      self.logger = LogsForMyFamily::Logger.new if !logger

      log_type = merged_config[:log_type]&.to_sym || :stdout
      error :log_type, "must be one of #{LOG_TYPES.map(&:to_s)}" if log_type && !LOG_TYPES.include?(log_type)

      log_level = merged_config[:log_level]&.to_sym || :info
      unless LogsForMyFamily::Logger::LEVELS.include?(log_level)
        error :log_level, "must be one of #{LogsForMyFamily::Logger::LEVELS}"
      end

      backend =
        if log_type == :file
          log_file = merged_config[:log_file] || 'configurator.log'
          if logs_directory.nil?
            error :log_type, 'must set logs directory with -l or $LOGS_DIRECTORY to set log_type to file'
          else
            FileLogWriter.new(File.join(logs_directory, log_file))
          end
        else
          StdoutLogWriter.new
        end

      # If we couldn't initialize everything then it's probably not worth exploding
      # on any missing dependencies -- that's an obvious consquence, and the addiitional
      # noise might mask the root cause.
      return if errors?

      logger.filter_level(log_level)
      logger.backends = [backend]

      self.refresh_interval = merged_config[:refresh_interval]
      self.client_id = merged_config[:client_id]

      self.dependencies = service_defs.each_with_object({}) do |(name, service), template_to_services|
        service.templates.each do |template|
          template = template.to_sym
          if !template_defs.key?(template)
            error :services, { name => "references undefined template #{template}" }
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

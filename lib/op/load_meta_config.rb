# frozen_string_literal: true

require 'lifecycle/op_base'
require 'configurator_types'

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

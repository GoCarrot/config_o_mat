# frozen_string_literal: true

require 'lifecycle/op_base'
require 'optparse'

module Op
  class ParseCli < Lifecycle::OpBase
    reads :argv, :env
    writes :configuration_directory, :runtime_directory, :logs_directory, :early_exit

    # Add expand_path to string because the safe accessor is nice to use.
    module CoreExt
      refine String do
        def expand_path
          File.expand_path(self)
        end
      end
    end

    using CoreExt

    def call
      self.early_exit = false

      parser = OptionParser.new do |opts|
        opts.on('-v', '--version', 'Display the version') do
          self.early_exit = true
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          self.early_exit = true
        end

        opts.on(
          '-c', '--configuration-directory directory',
          'Read configuration from the given directory instead of from $CONFIGURATION_DIRECTORY'
        ) do |dir|
          self.configuration_directory = dir
        end

        opts.on(
          '-r', '--runtime-directory directory',
          'Use the given directory for writing templates instead of $RUNTIME_DIRECTORY'
        ) do |dir|
          self.runtime_directory = dir
        end

        opts.on(
          '-l', '--logs-directory directory',
          'Use the given directory for writing log files instead of $LOGS_DIRECTORY'
        ) do |dir|
          self.logs_directory = dir
        end
      end

      parser.parse(argv)

      self.configuration_directory ||= env['CONFIGURATION_DIRECTORY']
      self.runtime_directory ||= env['RUNTIME_DIRECTORY']
      self.logs_directory ||= env['LOGS_DIRECTORY']

      self.configuration_directory = configuration_directory&.expand_path
      self.runtime_directory = runtime_directory&.expand_path
    end

    def validate
      return if early_exit

      if configuration_directory.nil? || configuration_directory.empty?
        error :configuration_directory, 'must be present'
      end

      error :runtime_directory, 'must be present' if runtime_directory.nil? || runtime_directory.empty?
    end
  end
end

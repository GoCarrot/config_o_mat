# frozen_string_literal: true

# Copyright 2021 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'yaml'
require 'digest'

module ConfigOMat
  class LogWriter
    def call(level_name, event_type, merged_data)
      merged_data[:level] = level_name
      merged_data[:event_type] = event_type

      write { "#{JSON.generate(merged_data)}\n" }
    end
  end

  class StdoutLogWriter < LogWriter
    def write
      $stdout.write(yield)
      $stdout.flush
    end
  end

  class FileLogWriter < LogWriter
    attr_reader :file_path

    def initialize(file_path)
      @file_path = file_path
    end

    def write
      File.open(@file_path, 'a') { |f| f.write(yield) }
    end
  end

  class ConfigItem
    class ValidationError < RuntimeError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.to_s)
      end
    end

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

    def ==(other)
      eql?(other)
    end
  end

  class Service < ConfigItem
    RESTART_MODES = %i[restart flip_flop restart_all].freeze

    attr_reader :systemd_unit, :restart_mode, :templates

    def initialize(opts)
      @systemd_unit = (opts[:systemd_unit] || '')
      @restart_mode = opts[:restart_mode]&.to_sym
      @templates = opts[:templates]

      if @restart_mode == :flip_flop && !@systemd_unit.include?('@')
        @systemd_unit = "#{@systemd_unit}@"
      elsif @restart_mode == :restart_all
        if @systemd_unit.include?('@')
          if !@systemd_unit.end_with?('\\x2a')
            @systemd_unit = "#{@systemd_unit}\\x2a"
          end
        else
          @systemd_unit = "#{@systemd_unit}@\\x2a"
        end
      end
    end

    def validate
      error :templates, 'must be present' if @templates.nil? || @templates.empty?
      unless @templates.is_a?(Array) && @templates.all? { |v| v.is_a?(String) }
        error :templates, 'must be an array of strings'
      end
      error :systemd_unit, 'must be present' if @systemd_unit.nil? || @systemd_unit.empty? || @systemd_unit == '@'
      error :restart_mode, "must be one of #{RESTART_MODES}" unless RESTART_MODES.include?(@restart_mode)

      if @restart_mode == :flip_flop && !@systemd_unit.end_with?('@')
        error :systemd_unit, 'must not contain an instance (anything after a @)'
      end

      if restart_mode == :restart && @systemd_unit.end_with?('@')
        error :systemd_unit, 'must not be a naked instantiated unit when restart_mode=restart'
      end

      if restart_mode == :restart_all && !@systemd_unit.end_with?('@\\x2a')
        error :systemd_unit, 'must not be an instantiated unit when restart_mode=restart_all'
      end
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

  class LoadedProfile < ConfigItem
    attr_reader :name, :version, :contents

    PARSERS = {
      'text/plain' => proc { |str| str },
      'application/json' => proc { |str| JSON.parse(str, symbolize_names: true) },
      'application/x-yaml' => proc { |str| YAML.safe_load(str, symbolize_names: true) }
    }.freeze

    def initialize(name, version, contents, content_type)
      @name = name
      @version = version

      parser = PARSERS[content_type]

      if parser
        begin
          @contents = parser.call(contents)
        rescue StandardError => e
          error :contents, e
        end
      else
        error :content_type, "must be one of #{PARSERS.keys}"
      end
    end

    def validate
      error :name, 'must be present' if @name.nil? || @name.empty?
      error :name, 'must be a Symbol' unless @name.is_a?(Symbol)
      error :version, 'must be present' if @version.nil? || @version.empty?
      error :contents, 'must be present' if @contents.nil? || @contents.empty?
    end

    def hash
      @name.hash ^ @version.hash ^ @contents.hash
    end

    def to_h
      @contents
    end

    def eql?(other)
      return false if !super(other)
      return false if other.version != version || other.contents != contents || other.name != name
      true
    end
  end

  class GeneratedTemplate < ConfigItem
    attr_reader :digest

    def initialize(contents)
      @digest = Digest::SHA256.hexdigest(contents)
    end

    def validate
    end

    def hash
      @digest.hash
    end

    def eql?(other)
      return false if !super(other)
      return false if other.digest != digest
      true
    end
  end
end

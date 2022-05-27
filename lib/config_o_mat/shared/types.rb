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

require 'facter'

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

    attr_reader :systemd_unit, :restart_mode, :templates, :restart_unit

    def initialize(opts)
      @systemd_unit = (opts[:systemd_unit] || '')
      @restart_mode = opts[:restart_mode]&.to_sym
      @templates = opts[:templates]

      if (@restart_mode == :flip_flop || @restart_mode == :restart_all) && !@systemd_unit.include?('@')
        @systemd_unit = "#{@systemd_unit}@"
      end

      @restart_unit = @systemd_unit

      if @restart_mode == :restart_all
        @restart_unit = "#{@restart_unit}\\x2a"
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

      if restart_mode == :restart_all && !@systemd_unit.end_with?('@')
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
    attr_reader :application, :environment, :profile, :s3_fallback

    def initialize(opts)
      @application = opts[:application]
      @environment = opts[:environment]
      @profile = opts[:profile]
      @s3_fallback = opts[:s3_fallback]
    end

    def validate
      error :application, 'must be present' if @application.nil? || @application.empty?
      error :environment, 'must be present' if @environment.nil? || @environment.empty?
      error :profile, 'must be present' if @profile.nil? || @profile.empty?
      if !@s3_fallback.nil?
        if @s3_fallback.kind_of?(String)
          error :s3_fallback, 'must be non-empty' if @s3_fallback.empty?
        else
          error :s3_fallback, 'must be a string'
        end
      end
    end

    def hash
      application.hash ^ environment.hash ^ profile.hash ^ s3_fallback.hash
    end

    def eql?(other)
      return false if !super(other)
      if other.application != application ||
         other.environment != environment ||
         other.profile != profile ||
         other.s3_fallback != s3_fallback
        return false
      end
      true
    end
  end

  class FacterProfile < ConfigItem
  end

  class LoadedFacterProfile < ConfigItem
    CLEAR_FROM_FACTER = [
      "memoryfree", "memoryfree_mb", "load_averages", "uptime", "system_uptime", "uptime_seconds", "uptime_hours", "uptime_days",
      {"ec2_metadata" => ["identity-credentials", "iam"]},
      {"memory" => [{"system" => ["capacity", "available_bytes", "used", "used_bytes", "available"] }] }
    ].freeze

    attr_reader :name, :version, :contents

    def initialize(name)
      @name = name
      load_from_facter
      @version = contents.hash
    end

    def fallback?
      false
    end

    def validate
      error :name, 'must be present' if @name.nil? || @name.empty?
      error :contents, 'must be present' if @contents.nil? || @contents.empty?
      error :contents, 'must be a hash' if !@contents.kind_of?(Hash)
    end

    def hash
      @name.hash ^ @version
    end

    def to_h
      @contents
    end

    def eql?(other)
      return false if !super(other)
      return false if other.version != version || other.name != name
      true
    end

  private

    def load_from_facter
      Facter.clear
      # This is to work around a bug in Facter wherein it fails to invalidate a second cache of the
      # IMDSv2 token.
      Facter::Resolvers::Ec2.instance_variable_set(:@v2_token, nil)
      new_facts = Facter.to_hash
      clear(new_facts, CLEAR_FROM_FACTER)
      transform(new_facts)
      @contents = new_facts
    end

    def clear(hash, diffs)
      diffs.each do |diff|
        if diff.kind_of?(Hash)
          diff.each do |(key, values)|
            clear(hash[key], values) if hash.key?(key)
          end
        elsif hash
          hash.delete(diff)
        end
      end
    end

    def transform(hash)
      return unless hash.kind_of?(Hash)
      hash.transform_keys!(&:to_sym)
      hash.default_proc = proc { |hash, key| raise KeyError.new("No key #{key.inspect} in profile #{name}", key: key, receiver: hash) }
      hash.each_value do |value|
        if value.kind_of?(Hash)
          transform(value)
        elsif value.kind_of?(Array)
          value.each { |v| transform(v) }
        end
      end
    end
  end

  class LoadedAppconfigProfile < ConfigItem
    attr_reader :name, :version, :contents, :secret_defs

    PARSERS = {
      'text/plain' => proc { |str| str },
      'application/json' => proc { |str| JSON.parse(str, symbolize_names: true) },
      'application/x-yaml' => proc { |str| YAML.safe_load(str, symbolize_names: true) }
    }.freeze

    def initialize(name, version, contents, content_type, fallback = false)
      @name = name
      @version = version
      @secret_defs = {}
      @fallback = fallback
      @chaos_config = false

      parser = PARSERS[content_type]

      if parser
        begin
          @contents = parser.call(contents)
          if @contents.kind_of?(Hash)
            parse_secrets
            @chaos_config = @contents.fetch(:"aws:chaos_config", false)
            @contents.default_proc = proc do |hash, key|
              raise KeyError.new("No key #{key.inspect} in profile #{name}", key: key, receiver: hash)
            end
          end
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
      @name.hash ^ @version.hash ^ @contents.hash ^ @fallback.hash ^ @chaos_config.hash
    end

    def to_h
      @contents
    end

    def fallback?
      @fallback
    end

    def chaos_config?
      @chaos_config
    end

    def eql?(other)
      return false if !super(other)
      if other.version != version ||
         other.contents != contents ||
         other.name != name ||
         other.fallback? != fallback? ||
         other.chaos_config? != chaos_config?
        return false
      end
      true
    end

  private

    def parse_secrets
      secret_entries = @contents.fetch(:"aws:secrets", nil)
      return if secret_entries.nil?

      error :contents_secrets, 'must be a dictionary' if !secret_entries.kind_of?(Hash)

      secret_entries.each do |(secret_name, secret_conf)|
        secret_def = Secret.new(secret_name, secret_conf)
        secret_def.validate
        error :"contents_secrets_#{secret_name}", secret_def.errors if secret_def.errors?

        @secret_defs[secret_name] = secret_def
      end
    end
  end

  class Secret < ConfigItem
    VALID_CONTENT_TYPES = LoadedAppconfigProfile::PARSERS.keys.freeze

    attr_reader :name, :secret_id, :version_id, :version_stage, :content_type

    def initialize(name, opts)
      @name = name
      @secret_id = opts[:secret_id]
      @version_id = opts[:version_id]
      @version_stage = opts[:version_stage]
      @content_type = opts[:content_type]&.downcase

      if (@version_id.nil? || @version_id.empty?) && (@version_stage.nil? || @version_stage.empty?)
        @version_stage = 'AWSCURRENT'
      end

      @content_type ||= 'application/json'
    end

    def validate
      error :secret_id, 'must be present' if @secret_id.nil? || @secret_id.empty?
      error :content_type, "must be one of #{VALID_CONTENT_TYPES}" unless VALID_CONTENT_TYPES.include?(@content_type)
    end

    def hash
      secret_id.hash ^ version_id.hash ^ version_stage.hash & content_type.hash
    end

    def eql?(other)
      return false if !super(other)
      if other.name != name ||
         other.secret_id != secret_id ||
         other.version_id != version_id ||
         other.version_stage != version_stage ||
         other.content_type != content_type
        return false
      end
      true
    end
  end

  class LoadedSecret < ConfigItem
    attr_reader :name, :secret_id, :version_id, :contents

    def initialize(name, secret_id, version_id, secret_string, content_type)
      @name = name
      @secret_id = secret_id
      @version_id = version_id

      begin
        @contents = LoadedAppconfigProfile::PARSERS[content_type].call(secret_string)
        if @contents.kind_of?(Hash)
          @contents.default_proc = proc do |hash, key|
            raise KeyError.new("No key #{key.inspect} in secret #{name}", key: key, receiver: hash)
          end
        end
      rescue StandardError => e
        error :contents, e
      end
    end

    def validate
      # Since name and version_id are coming from AWS and must be present, I'm not going to check
      # them here.
    end

    def hash
      @name.hash ^ @secret_id.hash ^ @version_id.hash ^ @contents.hash
    end

    def eql?(other)
      return false if !super(other)
      if other.name != name ||
         other.secret_id != secret_id ||
         other.version_id != version_id ||
         other.contents != contents
        return false
      end
      true
    end
  end


  class LoadedProfile < ConfigItem
    extend Forwardable

    attr_reader :secrets, :loaded_profile_data

    def_delegators :@loaded_profile_data, :name, :version, :contents, :fallback?

    def initialize(loaded_profile_data, secrets)
      @loaded_profile_data = loaded_profile_data
      @secrets = secrets || {}

      @errors = @loaded_profile_data.errors if @loaded_profile_data.errors?
    end

    def validate
    end

    def hash
      @loaded_profile_data.hash ^ @secrets.hash
    end

    def to_h
      contents
    end

    def eql?(other)
      return false if !super(other)
      return false if other.loaded_profile_data != @loaded_profile_data || other.secrets != @secrets
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

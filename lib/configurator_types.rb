# frozen_string_literal: true

require 'json'

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
    error :systemd_unit, 'must be present' if @systemd_unit.nil? || @systemd_unit.empty?
    error :restart_mode, "must be one of #{RESTART_MODES}" unless RESTART_MODES.include?(@restart_mode)
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

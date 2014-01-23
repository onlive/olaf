# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require "json"

require "olaf/errors"

module OLFramework
  class Settings
    def initialize(options = {})
      @fields = {}
      @values = {}
      @sync = {}
    end

    REGISTER_OPTIONS = [ :read_only, :from_file, :value ]

    #
    # Register a new top-level setting.  The setting value
    # may be a primitive, or collection like Hash or Array.
    #
    # It may also be sync'd from a file, which means we will
    # load from a JSON or YAML file as often as the file's
    # modification date changes (call #sync to check).
    #
    # @param name [String|Symbol] The name of the field
    # @param options Hash Options to set
    # @option options [Boolean] :read_only Whether the field is read-only
    # @option options [String] :from_file Sync from given filename
    # @option options [Object] :value The value to assign the field.
    #
    def register(name, options = {})
      bad_keys = options.keys - REGISTER_OPTIONS
      raise "Bad options: #{bad_keys.inspect}!" unless bad_keys.empty?

      name = name.to_s

      @fields[name] = options
      if options[:from_file]
        options[:from_file] = File.expand_path options[:from_file]
        sync(name)
      elsif options[:value]
        @values[name] = options[:value]
      end
    end

    protected

    def indifferent_freeze(item)
      if item.is_a? Hash
        ret = item.inject({}) do |h, (k, v)|
          fv = indifferent_freeze v
          h[k.to_sym] = fv
          h[k.to_s] = fv
          h
        end
        return ret.freeze
      end

      return item.map { |i| indifferent_freeze(i) } if item.is_a? Array

      item.freeze
    end

    EXTENSIONS = {
      "json" => proc { |s| JSON.parse(s) },
      "yaml" => proc { |s| YAML.load(s) },
      "yml" => proc { |s| YAML.load(s) },
    }

    # Query latest settings from file for a :from_file field,
    # if they are out of date.
    #
    # @param name [String] The filename as a string
    #
    def sync(name)
      name = name.to_s

      filename = @fields[name][:from_file]
      mtime = File.mtime filename
      if !@sync[name] || mtime != @sync[name]
        ext = filename.split(".")[-1]
        raise "Not a JSON or YAML file: #{filename}!" unless EXTENSIONS[ext]

        @values[name] = indifferent_freeze EXTENSIONS[ext].call(File.read filename)
        @sync[name] = mtime
      end
    end

    public

    def refresh
      @sync.each_key { |name| sync(name) }
    end

    def [](field)
      field = field.to_s

      unless @fields.has_key?(field)
        raise SettingNotFound, "No field: #{field.inspect}!"
      end

      @values[field]
    end

    def []=(field, value)
      field = field.to_s

      if !@fields.has_key?(field)
        raise SettingNotFound, "No field: #{field.inspect}!"
      elsif @fields[field][:read_only]
        raise SettingNoUpdate, "Read-only field: #{field.inspect}!"
      end

      @values[field] = value
    end

    def unregister(field, options = {})
      field = field.to_s

      if !@fields.has_key?(field)
        raise SettingNotFound, "No field: #{field.inspect}!"
      end

      @fields.delete(field)
      @values.delete(field)
    end
  end
end

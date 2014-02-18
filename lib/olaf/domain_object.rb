# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'olaf/errors'
require 'olaf/logger_helpers'
require 'olaf/service_helpers'
require 'olaf/domain_object_types'
require 'olaf/extensions/hash'
require 'olaf/extensions/uuid'

module Olaf
  module StandardFields
    def self.included(other)
      other.class_eval do
        field :id,          UUIDTools::UUID,  :create => false, :update => false
        field :updated_at,  DateTime,         :create => false, :update => false
        field :created_at,  DateTime,         :create => false, :update => false
      end
    end
  end

  class DomainObject
    extend Olaf::ServiceHelpers
    include Olaf::LoggerHelpers

    VALID_OPTIONS = [:create, :update, :readonly, :private]

    def initialize(hash)
      @hash = self.class.check_hash_against_domain_object(hash,  {:ignore_unknown_fields => true})
    end

    def to_hash()
      # I think it's scary to have people modifying this hash, so we return a copy
      @hash.dup
    end

    def self.inherited(by_class)
      logger_helper_inherited(by_class)
      by_class.do_setup
    end

    class << self
      attr_accessor :types, :options
    end

    def self.do_setup()
      @types = {}
      @options = {}
    end

    def self.field(name, type, options = {})
      # Define getter for field
      define_method(name) do
        return @hash[name.to_sym]
      end

      # Define setter
      define_method("#{name}=") do |val|
        # TODO this might need to be smarter re: admin rights, etc.
        raise Olaf::FieldUpdateError, {:message => "Field '#{name}' cannot be updated."} if self.class.options[name.to_sym].fetch(:readonly, false)
        # Should we type check here?
        @hash[name.to_sym] = val
      end

      # explicitly store the types as strings so that we can perform hash checking on them
      @types[name.to_s] = type
      bad_options = options.keys - VALID_OPTIONS
      bad_options.each do |option|
        raise Olaf::InvalidDomainObjectOption.new("Unknown option '#{option}' in field '#{name}' of class #{self}")
      end
      @options[name.to_sym] = options.reject {  }
    end

    def self.readonly_field(name, type, options = {})
      self.field(name, type, options.merge({:readonly => true}))
    end

    def ==(other)
      # to_hash returns a copy. Should we call to_hash on our local copy?
      return false if other.nil?

      return @hash == other.to_hash()
    end

    def self.check_hash_against_domain_object(hash, options)
      param_type_error("Value #{hash.inspect} is not a Hash, so cannot match #{self}.") unless hash.is_a?(Hash)

      bad_fields = []
      checked_hash = {}
      hash.keys.each() do | key |
        if @types.has_key?(key.to_s)
          # check hash value against type
          value = hash[key]

          # throws if this fails
          # this is safe now; checked_hash only has checked values.
          checked_hash[key.to_sym] = check_type_against_value(@types[key.to_s], value, options)

        elsif !options[:ignore_unknown_fields]
          bad_fields << key
        end
      end

      unless bad_fields.empty?
        param_type_error "Value #{hash.inspect} has disallowed fields #{bad_fields.inspect} that are not in type #{self}."
      end

      return checked_hash
    end

    def to_external_hash
      hash_to_externalize = @hash.dup
      @hash.each do |k,v|
        if self.class.options[k].fetch(:private, false)
          hash_to_externalize.delete(k)
        end
      end
      hash_to_externalize.camelize(:lower)
    end

    def to_json(*args)
      to_external_hash.to_json(*args)
    end

    def as_json(*args)
       to_external_hash.as_json(*args)
    end

    def self.from_external_hash(hash, is_array=false)
      # The hash is converted to snake case inside of initialize()
      if is_array
        array = hash.map do |obj|
          internalize_single_object(obj)
        end
        # Verify we got an array of all of the expected class
        # TODO: maybe checking array.any? { |elem| elem.is_nil? } is enough?
        if array.all? { |elem| elem.is_a? self }
          return array
        end

        # TODO: fix this access of logger
        logger.error "#{hash.inspect} failed to deserialize into an array of elements of type #{self.inspect}"
        return nil
      else
        return internalize_single_object(hash)
      end
    end

    def self.internalize_single_object(hash)
      begin
        ret = self.new(hash.underscore)  # convert to snake case
      rescue => e
        logger.error "#{hash.inspect} failed to be de-serialized into #{self.class} because of #{e.message}."
        return nil
      end

      return ret
    end

    def hash_for_create
      new_hash = @hash.dup
      # Delete any fields marked :create => false
      new_hash.delete_if {|key,val| !self.class.options[key.to_sym].fetch(:create, true)}
      bad_keys = @hash.keys - new_hash.keys
      DomainObject.logger.warn "Deleted fields for create: #{bad_keys.inspect}" unless bad_keys.empty?
      new_hash
    end

    def hash_for_update
      new_hash = @hash.dup
      # Delete any fields marked :update => false
      new_hash.delete_if {|key,val| !self.class.options[key.to_sym].fetch(:update, true)}
      bad_keys = @hash.keys - new_hash.keys
      DomainObject.logger.warn "Deleted fields for update: #{bad_keys.inspect}" unless bad_keys.empty?
      new_hash
    end

    # Temp
    def update_datamapper_model(dm_model)
      hash = hash_for_update
      # Only set when hash has the key and it's a valid attribute
      (dm_model.attributes.keys & hash.keys).each do |key, value|
        dm_model[key] = hash[key]
      end
    end

    def to_s
      @hash.to_s
    end
  end
end


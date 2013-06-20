# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

require "olaf/extensions/hash"

require "cassandra"

module OLFramework
  Consistency = ::CassandraThrift::ConsistencyLevel

  module Cassandra
    def self.client_setup(keyspace = 'Keyspace', servers = '127.0.0.1:9160',
                          thrift_options = {})
      if keyspace.is_a?(::Cassandra)
        # They just passed in a client object directly
        @client = keyspace
        return
      end

      STDERR.puts "Client is already set up!" if @client
      @client ||= ::Cassandra.new(keyspace, servers, thrift_options)
    end

    def self.client
      raise "No client configuration!" unless @client
      @client
    end

    def self.client?
      !!@client
    end
  end

  # This is the Cassandra equivalent of both PersistentResource and
  # StandardProperties.
  #
  module CassandraProperties
    def self.included(other)
      other.extend ClassMethods
      other.class_eval do
        include ::Olaf::CassandraProperties::InstanceMethods
      end
    end

    module ClassMethods
      attr_reader :properties
      attr_accessor :column_family

      def sanity_check
        raise "No column family set!" unless @column_family
      end

      # Declare a property with a name and type.  Options include
      # :required and :default.
      #
      def property(name, type = ::String, options = {})
        # If unspecified, default to QUORUM/QUORUM
        options[:consistency] ||= {
          :write => Consistency::QUORUM,
          :read => Consistency::QUORUM
        }

        @properties ||= {}
        raise "Duplicate property #{name}!" if @properties[name]
        @properties[name] = [ name, type, options ]
      end

      def create(values)
        sanity_check

        uuid = values[:uuid] || UUIDTools::UUID.random_create

        inst = self.new uuid, values
        inst.save

        inst
      end

      def find(uuid)
        sanity_check

        # Sort by read consistency
        rcs = {}

        @properties.each_value do |name, type, options|
          rc = options[:consistency][:read]
          rcs[rc] ||= []
          rcs[rc].push name
        end

        # Get at each consistency, then merge the results.
        values = rcs.map do |consistency, column_names|
          cassandra_client.get column_family, uuid, column_names.map(&:to_s),
            :consistency => consistency
        end.inject({}, &:merge)

        self.new uuid, values
      end

      private

      def cassandra_client
        Olaf::Cassandra.client
      end

    end

    module InstanceMethods
      def initialize(uuid = UUIDTools::UUID.random_create, values = {})
        self.class.sanity_check

        @uuid = uuid

        # TODO: check which values correspond to properties
        @values = values.convert_keys_to_strings
      end

      def uuid
        @uuid
      end

      def save
        self.class.sanity_check

        # Sort by write consistency
        wcs = {}

        self.class.properties.each_value do |name, type, options|
          wc = options[:consistency][:write]
          wcs[wc] ||= []
          wcs[wc].push name
        end

        # Insert at each consistency
        wcs.map do |consistency, column_names|
          # TODO: right now, we ignore unset values.  Delete them?
          col_hash = @values.slice(column_names.map(&:to_s))
          next if col_hash.empty?
          cassandra_client.insert self.class.column_family, uuid, col_hash,
            :consistency => consistency
        end
      end

      private

      def cassandra_client
        Olaf::Cassandra.client
      end

      public

      def method_missing(method_name, *args, &block)
        if self.class.properties[method_name]
          self.class.class_eval do
            define_method(method_name) do
              @values ||= {}
              @values[method_name.to_s]
            end
          end
          return self.send(method_name, *args, &block)
        elsif method_name.to_s[-1] == "="
          prop_name = method_name.to_s[0..-2]
          self.class.class_eval do
            define_method(method_name) do |value|
              @values ||= {}
              @values[prop_name] = value
            end
          end
          return self.send(method_name, *args, &block)
        end
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        self.class.properties[method_name] || super
      end
    end
  end

=begin
  # Standard properties for a persistent resource. Adds autogenerated UUID id,
  # createdAt and updatedAt.
  #
  #Example usage:
  #
  # class MyRecord
  #   include OLFramework::PersistentResource
  #   include OLFramework::StandardProperties
  # end
  #
  module StandardProperties
    def self.included(other)
      other.class_eval do
        property :id, DataMapper::Property::UUID, :key => true, :required => true,
                                                  :default => Proc.new { UUIDTools::UUID.random_create.to_s }

        before :create do
          # force a new ID; we don't want to allow someone to manually set something
          # TODO: I tried to take out the :default key above, but it leads to rejected
          # values when you try to create a new object without passing an ID? So I'm going to leave it.
          @id = UUIDTools::UUID.random_create.to_s
        end

        def attribute_actually_dirty(attrib)
          return attribute_dirty?(attrib) &&
              original_attributes[properties[attrib]] != dirty_attributes[properties[attrib]]
        end

        before :update do
          # TODO: add exact arguments here...
          if attribute_actually_dirty(:id) || attribute_actually_dirty(:created_at)
            # TODO: how to enforce people not manually updating updated_at?
            raise ArgumentError, "Failing update of id or created_at field; cannot be changed in an update."
          end
        end
      end
    end
  end
=end
end

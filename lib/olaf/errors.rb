# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'multi_json'
require "olaf/extensions/exception"

module OLFramework
  ERROR_CODE_BASE = 1000

  # Default framework exception
  class Error < StandardError
    OLERROR_OPTIONS = [:http_response_code, :error_code, :request_guid, :reason, :message]

    def initialize(options)
      bad_keys = options.keys - OLERROR_OPTIONS

      STDERR.puts "OLFrameworkError: Creating with bad options: #{bad_keys.inspect}" if bad_keys.length > 0
      STDERR.puts "OLFrameworkError: You MUST provide error_code" if options[:error_code].nil?
      # Commenting out this error message because the request_guid gets added to the exception in the
      # controller error block
      #STDERR.puts "OLFrameworkError: You MUST provide request_guid" if options[:request_guid].nil?

      super(options[:message] || "#{self.class}: error_code #{options[:error_code]}, http_status #{options[:http_response_code]}")

      @error_code = options[:error_code]
      @http_response_code = options[:http_response_code]
      @request_guid = options[:request_guid]
      @reason = options[:reason]
    end

    def to_ol_hash
      # We monkey-patch Exception class and add to_ol_hash
      data = super.merge( {
        :request_guid => request_guid,
        :error_code => error_code,
			  :backtrace => filtered_backtrace } )

      if reason && reason.is_a?(Exception)
        data.merge!(:reason => reason.to_ol_hash)
      end

      data
    end

    attr_reader   :http_response_code
    attr_reader   :error_code
    attr_accessor :request_guid
    attr_reader   :reason

    alias http_code http_response_code
    alias http_status http_response_code

    FILTER_GEMS = [ "sinatra", "rack", "thin", "eventmachine" ]

    def filtered_backtrace
      bt = (self.backtrace || []).map do |line|
        if FILTER_GEMS.any? { |gem| line["gems/#{gem}-"] }
          nil
        else
          line
        end
      end

      bt.compact
    end

    # Creates a new subclass of OLFrameworkError with
    # error code and response code
    # @param [Fixnum] error_code Error code
    # @param [Fixnum] response_code HTTP response code
    # @return [Class]
    def self.define_error(error_code, http_status, parent_klass)
      Class.new(parent_klass) do
        define_method(:initialize) do |*args|
          if args.length == 1 && args[0].is_a?(String)
            arg = { :message => args[0] }
          elsif args.length == 1 && args[0].respond_to?(:to_h)
            arg = args[0].to_h
          elsif args.length == 0
            arg = {}
          else
            raise "Illegal args #{args.inspect} creating Olaf::Error!"
          end
          super( {:error_code => error_code, :http_response_code => http_status}.merge(arg) )
        end
      end
    end
  end

  # Convenience helper
  def self.define_error(error_code, response_code = BAD_REQUEST, parent_klass = Error)
    Error.define_error(error_code, response_code, parent_klass)
  end

  GenericError = define_error(1000, 400)
  InvalidGuid = define_error(1001, 400)
  InvalidJson = define_error(1002, 400)
  ParamTypeError = define_error(1003, 400)
  APIContractError = define_error(1004, 400)
  ObjectNotFound = define_error(1005, 404)
  # Added prefix to avoid collisions with std exception
  OLArgumentError = define_error(1006, 400)
  UnknownError = define_error(1007, 500)
  GenericRestClientError = define_error(1008, 500)
  FieldUpdateError = define_error(1009, 400) # Thrown when you try to update a field that is :readonly => true
  SettingNotFound = define_error(1010, 400)  # Try to modify nonexistent setting
  SettingNoUpdate = define_error(1011, 400, APIContractError)  # Try to modify read-only setting
  InvalidDomainObjectOption = define_error(1012, 400) # Raised when there is an unrecognized option in a field definition for an object

end


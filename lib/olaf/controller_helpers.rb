# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require "olaf/errors"
require "olaf/logger_helpers"
require "olaf/service_helpers"

module Sinatra
  module Helpers
    # Override this to treat unknown error codes as server errors in dev
    def server_error?
      status.between? 500, 599 or
          (settings.development? and not informational? and not success? and not redirect? and not client_error?)
    end
  end
end

module OLControllerHelpers
  #include OLFramework::LoggerHelpers
  include OLFramework::ServiceHelpers

  # common helpers here

  def parse_json_body_safe(convert_to_symbols = true)
    hash = nil
    begin
      hash = JSON.parse(request.body.string)
    rescue
      #logger.debug request.body.string
      raise OLFramework::InvalidJson
    end
    if convert_to_symbols then
      Hash.convert_keys_to_symbols(hash)
    else
      hash
    end
  end

  def request_headers
    if env['request.headers']
      return env['request.headers']
    end
    hh = env.select {|k,v| k.start_with? 'HTTP_'}
    env['request.headers'] = hh
  end

  def auth_token
    request.env['auth.token']
  end

  def request_tenant_id
    return request.env['auth.token'].tenant_guid if request.env['auth.token']
    nil
  end

  def check_return_type(route_properties, response)
    # if return type is not defined, then bail. route_properties may not always be set in tests.
    return false if route_properties.nil? || route_properties[:return_type].nil? || response.return_value == OLFramework::ReturnValue::None

    # don't fail type-checking if this is an error
    return false unless response.status.between?(200, 299)

    begin
      check_type_against_value(route_properties[:return_type], response.return_value)
      return true
    rescue => e
      self.class.logger.error "Type checking failed: #{route_properties[:route_name]} did not return a #{route_properties[:return_type]}. See error: #{e.message}"
      self.class.logger.error e.backtrace.join "\n"
      return false
    end

  end

  # TODO: needed for tenant_controller; remove after that usage is gone.
  def strip_params_before_orm(hash)
    new_hash = hash.dup
    new_hash.delete("route_properties")
    new_hash.delete("data_object")

    return new_hash
  end

end

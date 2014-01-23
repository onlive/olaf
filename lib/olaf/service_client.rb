# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'olaf/extensions/hash'
require 'olaf/extensions/uuid'
require 'olaf/http'
require 'olaf/logger_helpers'

require 'rest_client'
require 'rack/commonlogger'
require 'uri'
require 'ostruct'

module OLFramework

  # CommonLogger for local service calls
  class LocalCommonLogger < Rack::CommonLogger

    def call(env)
      began_at = Time.now
      status, header, body = @app.call(env)
      log(env, status, "", began_at)
      [status, header, body]
    end

  end

  # Service client
  class ServiceClient
    include OLFramework::LoggerHelpers

    attr_reader :service_name, :url

    ACCEPT = :json
    DEFAULT_HEADERS = {:content_type => :json}

    def initialize(service_name, url = nil)
      @service_name = service_name
      @url = url.to_s.dup
      @url.chomp!("/") if @url
    end

    def service_name=(sn)
      @service_name = sn
      @sc_is_initialized = false
    end

    def do_setup
      return if @sc_is_initialized
      @sc_is_initialized = true

      # Clear if reinitializing
      @resource = @url = @site = @service = nil

      # Check resource list -- which resource is this?
      # We do this by checking singular and plural versions of
      # the service name ("application", "applications") against
      # the resource's name and the name of the service class,
      # if any.  If anything matches, that was it.

      service_names = [ @service_name.downcase, @service_name.downcase + "s" ]
      OLFramework.resources.each do |name, resource|
        rsc_svc = resource[:service] ? resource[:service].name : nil
        rsc_name = rsc_svc ? rsc_svc[0..-8] : ""
        if service_names.include?(name.downcase) ||
            service_names.include?(rsc_name.downcase)
          @resource = resource
          @url = resource[:url].to_s.dup unless @url
          @url.chomp!("/") if @url
          break
        end
      end

      if @resource
        STDERR.puts "No URL set for service #{@service_name}!" unless @url
        STDERR.puts "No Service object for service " +
          "#{@service_name}!" unless @resource[:service]
      else
        STDERR.puts "Can't locate registered service #{@service_name.inspect}!"
      end

      unless @url || (@resource && @resource[:service])
        raise RuntimeError, "Can't use service #@service_name without " +
          "a URL or local implementation!"
      end

      @service = @resource[:service]
      # Create common logger for local calls only
      @local_common_logger = LocalCommonLogger.new(@service.application)
    end

    HTTP_VERBS_WITH_PAYLOAD = [ :post, :put, :patch ]
    HTTP_VERBS = HTTP_VERBS_WITH_PAYLOAD + [ :get, :delete, :head, :options ]

    CONTEXT_FIELDS = [ :headers, :raise, :route_properties ]

    #
    # We're using RestClient under the hood, and this API obeys
    # RestClient conventions.  Specifically:
    #
    # * for result code between 200 and 207 a response object will be
    #   returned.
    #
    # * for result code 301, 302 or 307 the redirection will be
    #   followed if the request is a get or a head.
    #
    # * for result code 303 the redirection will be followed and the
    #   request transformed into a get.
    #
    # * for other cases an exception holding the response will be
    #   raised.
    #
    # You can call .body or .to_s or .code on the response object.
    #
    # TODO: change this interface.  The RestClient interface may not
    # be optimal for HTTP requests and is clearly a little odd for
    # non-HTTP requests.  Either way, it should be basically the
    # same for HTTP and non-HTTP.
    #
    def perform_request(verb, path, params = {},
                        context = { :headers => { :accept => ACCEPT }})
      unless HTTP_VERBS.include?(verb)
        raise "#{verb.inspect} is not one of #{HTTP_VERBS.inspect}!"
      end

      do_setup

      context = context.convert_keys_to_symbols  # recursively
      headers = collect_headers(context)

      path, params = normalize_path_and_params(path, params) if path

      if @resource[:url]
        request_result = http_request(verb, path, params, headers)
      else
        # If no service URL, perform the request locally
        request_result = local_request(verb, path, params, context, headers)
      end

      body = request_result[:body]
      body = body.join("") if body.respond_to?(:each)

      got_error = request_result[:status] < 200 || request_result[:status] >= 400
      if got_error
        self.class.logger.error "ServiceClient got error: #{request_result[:status]}"
      end

      if context[:raise] && got_error
        error_hash = JSON.parse(body) rescue {}
        # Note: we don't set reason field because we try to rethrow the original exception here
        raise OLFramework::Error.new  :http_response_code => request_result[:status],
          :error_code => error_hash.fetch('error_code', 1000),
          :request_guid => headers[Http::REQUEST_GUID_HEADER],
          :message => "ServiceClient request failed: #{verb} #{path} message #{error_hash.fetch('message', 'unknown')}"
      else
        json = JSON.parse(body) rescue nil
        body = json || body
      end

      if got_error
        return_data = nil
      else
        object = create_data_object_from_body(context, body)
        return_data = object ? object : body
      end

      # "Raise" doesn't just mean raise.  It means to return
      # only one parameter if there was no error.
      return return_data if context[:raise]

      return return_data, request_result
    end

    private

    def local_request(verb, path, params, context, headers)
      # Grab the current Rack request environment and modify it
      env = OLFramework.last_request || {}
      env = new_env_for_request(env, verb, path, params, headers)

      unless @service
        raise "No service object was found for service #{@service_name}!"
      end

      begin
        # This will call @service.application.call(env)
        status, headers, body = @local_common_logger.call(env)

        return {
          :status => status,
          :headers => headers,
          # No cookies (yet?)
          :body => body
        }
      rescue
        return {
          :status => $!.respond_to?(:http_code) ? $!.http_code : 500,
          :body => $!.respond_to?(:http_body) ? $!.http_body : "",
          :reason => $!
        }
      end
    end

    def http_request(verb, path, params = {}, headers = { :accept => ACCEPT })
      raise "No URL defined!" unless @url

      # TODO: check service params, only pass through allowed

      args = [ verb, path ]
      if HTTP_VERBS_WITH_PAYLOAD.include?(verb)
        args += [ params, headers ]
      else
        # RestClient puts extra query params into the headers argument
        # as "params".  That's weird, and it results in the following
        # slightly weird line:
        args += [ headers.merge(:params => params) ]
      end

      ret_hash = nil
      begin
        rc_response = nil
        text_response = RestClient.send(*args) do |response, request, result, &block|
          rc_response = response
          # Use default behavior
          response.return!(request, result, &block)
        end
        ret_hash = {
          :status => rc_response.code.to_i,
          :body => text_response
        }
      rescue
        ret_hash = {
          :status => $!.respond_to?(:http_code) ? $!.http_code : 500,
          :body => $!.respond_to?(:http_body) ? $!.http_body : "",
          :reason => $!
        }
      end

      ret_hash
    end

    def collect_headers(context)
      headers = context[:headers] || { :accept => ACCEPT }

      # log an error when we see a context field we don't recognize.
      unrecognized_context = context.keys - CONTEXT_FIELDS
      unrecognized_context.each do |item_in_context_hash|
        self.class.logger.error "Ignoring field in context: #{item_in_context_hash.inspect}!"
      end

      if headers[:params]
        # RestClient does this, and I really wish it wouldn't.
        raise "You are using a horrible RestClient hack instead of params!"
      end

      # Request GUID
      cur_env = OLFramework.last_request || {}
      guid = cur_env[Http::CGI_REQUEST_GUID_HEADER]
      guid ||= UUIDTools::UUID.random_create.to_s
      headers[Http::REQUEST_GUID_HEADER] = guid

      headers
    end

    def normalize_path_and_params(path, params)
      # Normalize path
      path = "/#{path}"
      path.gsub!(/\/+/, "/")  # Substitute one slash for multiple slashes

      # Duplicate and convert symbols to strings
      params = Hash[*params.keys.flat_map { |k| [ k.to_s, params[k] ] }]

      # Extract query params if any
      path, param_string = path.split("?", 2)
      (param_string || "").split("&").each do |eq_string|
        key, val = eq_string.split("=", 2)
        params[key] = val
      end

      # URLs start with the service name *if* remote.
      # Local services call straight into the controller.
      u = ""
      u += @resource[:name].to_s if @resource[:url]
      u += path if path

      url_parts = substitute_vars_into_url(u, params)
      url_parts.unshift @url if @resource[:url]  # Prepend URL
      path = url_parts.join("/")

      return path, params
    end


    def setup_logger(env)
      # TODO: bad way to set up logging. Need to re-use logger from the service, which we don't have right now.
      logger = ::Logger.new(env['rack.errors'])
      logger.level = ::Logger::DEBUG
      env['rack.logger'] = logger
    end

    #
    # Create a new environment for the new request.
    #
    # Bug: right now, headers are copied from the old request
    # by default, so they may be set when they shouldn't
    # be.
    #
    # @todo Allow passing in input for PUT, POST and PATCH
    #
    def new_env_for_request(env, verb, path, params, headers)
      new_env = Rack::MockRequest.env_for(path,
                                          :method => verb.to_s.upcase,
                                          :params => params)
      new_env['rack.errors'] = env['rack.errors'] || STDOUT
      setup_logger( new_env )

      headers.each do |name, val|
        new_env["HTTP_#{name.to_s.upcase.gsub("-", "_")}"] = val
      end

      new_env
    end

    def substitute_vars_into_url(url, params)
      url_parts = url.split("/")
      url_parts.map do |part|
        if part[0] == ":"
          param_name = part[1..-1]  # Cut off leading colon
          value = params.delete(param_name)
          unless value
            raise RuntimeError, "No param matching #{param_name} to put in URL!"
          end
          URI.escape(value.to_s)
        else
          part  # Not a :param?  No change.
        end
      end
    end

    def create_data_object_from_body(context, body)
      # if return type is not defined, then bail. context[:route_properties] may not always be set in tests.
      if context[:route_properties].nil? || context[:route_properties][:return_type].nil?
        return nil
      end

      return_klass = context[:route_properties][:return_type]
      handle_array = return_klass.is_a?(Array)
      return_klass = return_klass[0] if handle_array

      if return_klass.respond_to?(:from_external_hash)
        # TODO: again, figure out if we're always going to be accessing body[0]
        if body.nil? || body.kind_of?(Array) && body[0].nil?
          return
        end

        data_object = return_klass.from_external_hash(body, handle_array)

        return data_object
      end

      return nil
    end

    public

    def get(resource, query = {}, headers = {})
      headers = headers.merge :accept => ACCEPT
      response = perform_request(:get, resource, query, headers)
      return JSON.parse(response.to_str)
    end

    # Returns unmarshalled hash
    def post(resource, data, headers = DEFAULT_HEADERS )
      new_headers = headers.merge( {:accept => ACCEPT} )
      response = perform_request(:post, resource, data, new_headers)
      return JSON.parse(response)
    end

    def put(resource, data, headers = DEFAULT_HEADERS )
      new_headers = headers.merge( {:accept => ACCEPT} )
      response = perform_request(:put, resource, data, new_headers)
      return JSON.parse(response)
    end

    def delete(resource, headers = {})
      new_headers = headers.merge( {:accept => ACCEPT} )
      response = perform_request(:delete, resource, {}, new_headers)
      return JSON.parse(response)
    end

  end
end

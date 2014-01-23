# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require "sinatra/base"
require "olaf/rack_helpers"
require "olaf/service_helpers"
require "olaf/service_swagger"
require "olaf/service_client"
require "olaf/controller"
require 'olaf/domain_object'
require 'olaf/log/inherited_class_logger'

module OLFramework
  class Service
    include OLFramework::InheritedClassLogger

    include ServiceHelpers
    extend ServiceSwagger

    class << self
      attr_reader :route_names
      attr_reader :request_types
    end

    def initialize
      STDERR.puts <<MSG
Please don't create a new instance of your service!  Instead, if you
want to run it in a config.ru file, call .application() on the class
to get an instance of a Sinatra application to use with Rack.
MSG
      raise RuntimeError, "Please don't call .new on a service!"
    end

    def self.inherited(by_class)
      logger_helper_inherited(by_class)
      by_class.do_setup
    end

    def self.service_name(name = nil)
      if name
        @service_name = name
        @internal_client.service_name = name
      end

      @service_name
    end

    def self.do_setup
      @name = self.name
      eval <<CODE
        class ::#{@name}Sinatra < OLFramework::Controller
        end
CODE
      @internal_sinatra = multi_const_get(@name + "Sinatra")
      @internal_client = ServiceClient.new(@service_name)

      @default_property = {}
      @next_property = {}
      @request_types = []
      @route_names = {}
      @path_descs = {}
    end

    def self.application
      @internal_sinatra
    end

    def self.client
      unless @internal_client
        raise "NO CLIENT FOUND!"
      end

      @internal_client
    end

    def self.default_property(name, value)
      name = name.to_sym
      @default_property[name] = value
    end

    def self.next_property(name, value)
      name = name.to_sym
      if @next_property[name]
        STDERR.puts "You initialized #{name.inspect} multiple times " +
          "before using it!  (Most recent: #{value.inspect})"
      end
      @next_property[name] = value
    end

    def self.default_content_type(value)
      default_property :content_type, value
    end

    #
    # Set up a Swagger (et al) description for a path, which may
    # include multiple routes with different verbs.  Eventually,
    # set up other data about the path rather than the route.
    #
    # @param path [String] The path to describe
    # @param options [Hash] Options with path data
    # @option options [String] :desc Description of the route
    #
    def self.api_path(path, options)
      @path_descs[path] = options
    end

    def self.route_name(value)
      next_property :route_name, value
    end

    def self.desc(value)
      next_property :desc, value
    end

    def self.param(paramName, paramType, paramDesc, options = {})
      @next_property[:param] ||= {}

      if @next_property[:param][paramName]
        STDERR.puts "You initialized parameter #{paramName.inspect} " +
          "multiple times before using it!"
      end

      @next_property[:param][paramName] = {
        :name => paramName,
        :type => paramType,
        :desc => paramDesc,
        :options => options
      }
    end

    def self.errors(error_hash)
      next_property :errors, error_hash
    end

    def self.return_type(ret_type)
      next_property :return_type, ret_type
    end

    # TODO: get complete list of all Sinatra-able HTTP verbs
    HTTP_VERBS = [:get, :put, :post, :head, :patch, :delete]

    # Define a convenience method for each HTTP verb
    metaclass = class << OLFramework::Service; self; end
    HTTP_VERBS.each do |verb|
      metaclass.class_eval do
        define_method(verb) do |path, options = {}, &action|
          request(path, options.merge(:via => verb), &action)
        end
      end
    end

    def self.request(path, options = {}, &action)
      options[:via] ||= :get
      options[:via] = options[:via].to_s.downcase.to_sym
      unless HTTP_VERBS.include?(options[:via])
        raise RuntimeError, "Invalid HTTP verb #{options[:via].inspect}!"
      end

      properties = @default_property.merge(@next_property)
      # "rt_name" so as not to conflict with the route_name method
      rt_name = properties[:route_name]

      # Save on the route list
      @request_types.push [path, options, properties, action]

      # Save as a route name, if any
      if rt_name
        if @route_names[rt_name]
          raise RuntimeError, "Duplicate route name #{rt_name.inspect}!"
        end
        @route_names[rt_name] = @request_types[-1]
      end

      # Prepend a slash to path
      path = "/" + path unless path[0] == "/"

      # TODO: do these on demand instead of at definition time
      add_request_to_application(path, properties, options, &action)
      add_request_to_client(path, properties, options, &action)

      @next_property = {}
    end

    def self.add_request_to_application(path, properties, options, &action)
      # Forward definition to Sinatra
      @internal_sinatra.send(options[:via], path, &action)

      @internal_sinatra.send(:before, path) do
        # Sinatra "before" actions aren't verb-specific, so check the verb.
        return unless request.request_method.downcase.to_sym == options[:via]

        logger.debug "sinatra_before #{path} in #{self.class.name}" if settings.log_before_after

        OLFramework.current_request_stack ||= []
        OLFramework.current_request_stack.push request.env

        # Validate parameters
        #STDERR.puts "(FAKE) Validating params for #{path.inspect}..."

        if properties.has_key?(:param)
          new_params = OLFramework::Service.transform_parameters(properties, request, @params)
          unless new_params == @params
            @params = indifferent_params(new_params)
          end
        end
      end

      @internal_sinatra.send(:after, path) do
        # Sinatra "after" actions aren't verb-specific, so check the verb.
        return unless request.request_method.downcase.to_sym == options[:via]

        logger.debug "sinatra_after #{path} in #{self.class.name}" if settings.log_before_after

        # TODO: Add default content type

        if check_return_type(properties, response)
          body(response.return_value.to_json)
        end

        req_stack = OLFramework.current_request_stack
        if req_stack[-1] == request.env
          req_stack.pop
          return
        end

        STDERR.print "Request stack does not match!\nDepth: #{req_stack.size}\nENV: #{request.env['PATH_INFO']}\n" +
          "  #{req_stack[-1]['PATH_INFO']}\n"

        if req_stack.include?(request.env)
          # Remove all environments at or after the one being popped.
          req_stack.pop until req_stack[-1].object_id == request.env.object_id
          req_stack.pop
        end

      end
    end

    def self.transform_parameters(properties, request, params)
      # TODO: Do we want to consider just storing the property names as strings?
      properties[:param].each do |key, val|
        # Check if this route has a body param. If so, check that the params has a parameter of the same name
        # as the body param. We only convert body params because we do not currently have a use-case where
        # we would be passing a DomainObject as a query param.
        if val[:options][:type] == :body
          if params.has_key?(key.to_s)
            # If it does have this key, just grab the value so we can try to internalize it
            new_body = params[key.to_s]
          else
            # If not, we have to add it to params, and move the body params inside of it
            new_body = request.POST.dup
            # Delete the values from the top-level hash
            new_body.each do |pkey, pval|
              request.delete_param(pkey)
              params.delete(pkey)
            end
          end

          # And update the params
          # If the body param is a domain object, internalize it and set it in the params instead
          # of the hash
          param_class = val[:type]
          if param_class < OLFramework::DomainObject
            request[:orig_body] = new_body
            # to_internal_hash will strip unknown fields and return nil if it encounters any bad fields
            obj = param_class.from_external_hash(new_body)
            if obj.nil?
              raise OLArgumentError.new("Failed to internalize arguments into type #{param_class.inspect}")
            end
            request.update_param(key.to_s, obj)
          else
            request.update_param(key.to_s, new_body)
          end

          params = params.merge(request.params)
        end
      end
      params
    end

    def self.add_request_to_client(path, properties, options, &action)
      route_name = properties[:route_name]
      return unless route_name

      # TODO: make non-bang version *not* send :raise => true

      # Define default non-bang version of method
      @internal_client.send(:define_singleton_method, route_name,
                            lambda do |local_params,
                                       context = {
                                         :headers => { :accept => :json } }|
                              perform_request(options[:via].to_sym, path,
                                              local_params,
                                              {:route_properties => properties}.merge(context))
                            end)

      # Define success-or-raise, bang version of method
      @internal_client.send(:define_singleton_method, "#{route_name}!",
                            lambda do |local_params,
                                       context = {
                                         :headers => { :accept => :json },
                                         :route_properties => properties }|
                              perform_request(options[:via].to_sym, path,
                                              local_params,
                                              context.merge(:raise => true, :route_properties => properties))
                            end)
    end

    # Based on http://stackoverflow.com/questions/1598484/how-to-get-the-nested-modules-dynamically-from-an-object
    def self.multi_const_get(full_name)
      const_list = full_name.split('::').inject([Object]) do |hierarchy,name|
        hierarchy << hierarchy.last.const_get(name)
      end

      const_list[-1]
    end
  end
end

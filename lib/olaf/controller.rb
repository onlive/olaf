# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require "rack/parser"
require "rack/logger"
require "sinatra/base"
require "sinatra/cookies"
require "rest_client"
require "dm-core"

require "olaf/controller_helpers"
require "olaf/test_logger"
require "olaf/full_request_logger"
require "olaf/request_guid_generator"
require "olaf/errors"
require "olaf/extensions/sinatra_response"

module OLFramework
  # Common controller class that every controller should inherit from.
  class Controller < Sinatra::Base
    helpers OLControllerHelpers

    class << self; attr_accessor :authenticator, :olaf_settings end

    ### Sinatra settings
    set :root, Dir.pwd
    set :frame_root, Proc.new { ENV['FRAMEWORK_ROOT'] || File.join(settings.root, "..", "olaf") }

    ### Conditions for Routes
    set :on_port, proc { |value| condition { request.port == value } }

    ### Middleware


    error ArgumentError do
      exception = request.env["sinatra.error"]

      logger.info("Caught ArgumentError: #{exception.message}")
      status 400
      body OLFramework::OLArgumentError.new(:message => exception.message, :reason => exception, :request_guid => request.guid).to_ol_hash.to_json
    end

    error DataMapper::ObjectNotFoundError do
      exception = request.env["sinatra.error"]

      logger.info("Caught #{exception.class}: #{exception.message}")
      status 404
      body OLFramework::ObjectNotFound.new(:message => exception.message, :reason => exception, :request_guid => request.guid).to_ol_hash.to_json
    end

    error OLFramework::Error do
      exception = request.env["sinatra.error"]
      # Make sure we don't overwrite the guid in case it was set somewhere else (should always be the same but just in case)
      exception.request_guid = request.guid unless exception.request_guid
      STDERR.puts "OLFrameworkError: No request_guid for exception" unless exception.request_guid
      logger.info("Caught #{exception.class}: #{exception.message}")
      status exception.http_status
      body exception.to_ol_hash.to_json
    end

    error RestClient::Exception do
      exception = request.env["sinatra.error"]

      logger.info("Caught #{exception.class}: #{exception.message}")
      status exception.http_code
      body OLFramework::GenericRestClientError.new(:http_response_code => exception.http_code, :message => exception.message, :reason => exception, :request_guid => request.guid).to_ol_hash.to_json
    end

    error do
      exception = request.env["sinatra.error"]
      logger.info "OLFramework::Controller.error: #{exception.class}"

      msg = ["Caught #{exception.class} - #{exception.message}:"]
      msg.concat(exception.backtrace)
      logger.info msg.join("\n")
      status 500
      body OLFramework::UnknownError.new(:message => exception.message, :reason => exception, :request_guid => request.guid).to_ol_hash.to_json
    end

    configure do
      enable :logging
      set :log_before_after, false
      #set :logging, Logger::DEBUG

      # Allow error dump to stderr but disable raising errors. Without this,
      # error handler above won't be called
      set :show_exceptions, false
      set :raise_errors, false
      # Uncomment this to dump callstacks
      # set(:dump_errors, true)

      # ======= Rack Middleware ================================

      use OLFramework::RequestGuidGenerator

      if ENV['DUMP_REQUESTS']
        STDERR.puts "Enabling full request logger"
        use OLFramework::FullRequestLogger
      end

      # Auto-parse application/json bodies into request.params
      # TODO(petef): customize error handling
      use Rack::Parser, :content_types => {
          "application/json" => Proc.new { |body| JSON.load(body) }
      }
    end

    configure :test do
      enable :logging
      if ENV['LOG_BEFORE_AFTER']
        set :log_before_after, true
      end
    end

    # Override Sinatra's setup_custom_logger
    class << self
      private

      # This sets up a common logger
      def setup_common_logger(builder)
        if settings.environment == :test
          #Annoying, not doing this
          #builder.use Sinatra::CommonLogger, STDOUT
        else
          builder.use Sinatra::CommonLogger
        end
      end

      def setup_custom_logger(builder)
        # By default, sinatra sets up Rack::Logger which uses env[rack.errors], which
        # in turn is overwritten in MockRequest. We want to see logs in the test environment
        if settings.environment == :test
          builder.use OLFramework::TestLogger, Logger::DEBUG
        else
          #STDERR.puts "#{self.inspect}: Setting up Rack::Logger"
          if logging.respond_to? :to_int
            builder.use Rack::Logger, logging
          else
            builder.use Rack::Logger
          end
        end
      end

    end

    options '/' do
      headers 'Allow' => 'GET,HEAD,POST,OPTIONS,PUT'
      status 200
    end

    # Note: Sinatra's before handler is invoked after other middleware filters we set
    # up in the configure block
    before do
      logger.debug "sinatra_before in #{self.class.name}" if settings.log_before_after

      # Copy settings from global
      self.class.olaf_settings = OLFramework.settings_for_request

      cache_control :no_cache

      if self.class.authenticator
        if !self.class.authenticator.authenticate_request(request)
          # TODO: do we need to provide more information here?
          halt 401
        end
      end

      # Pagination: DataMapper supports limit and offset parameters. We might want to change this in the future
      # Also, if we select different db middleware, filter can be separated from pagination
      # and other options. Please keep commented out code
      # request.env['options'] = {}
      if params.has_key?('limit') || params.has_key?('offset')

        # Convert fields to integer because DataMapper is stupid
        begin
          params['limit'] = Integer(params['limit']) if params.has_key? 'limit'
          params['offset'] = Integer(params['offset']) if params.has_key? 'offset'
        rescue ArgumentError, TypeError
          params.delete('limit')
          params.delete('offset')
        end
      end
    end

    def return_value(val)
      response.return_value(val)
    end

    # We override process_route to not blindly revert @params at the end, but
    # just remove the 'splat' and 'captures' values from params, or else in
    # some cases, our changes to params in before blocks get overwritten
    # TODO: find better way? File bug against Sinatra?
    def process_route(pattern, keys, conditions, block = nil, values = [])
      route = @request.path_info
      route = '/' if route.empty? and not settings.empty_path_info?
      return unless match = pattern.match(route)
      values += match.captures.to_a.map { |v| force_encoding URI.decode(v) if v }

      if values.any?
        original, @params = params, params.merge('splat' => [], 'captures' => values)
        keys.zip(values) { |k,v| Array === @params[k] ? @params[k] << v : @params[k] = v if v }
      end

      catch(:pass) do
        conditions.each { |c| throw :pass if c.bind(self).call == false }
        block ? block[self, values] : yield(self, values)
      end
    ensure
      # Original:
      # @params = original if original
      @params.delete('splat')
      @params.delete('captures')
    end

  end
end

# Make sure settings_for_request is loaded
require "olaf"

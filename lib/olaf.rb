# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

require "bundler"
Bundler.require(:default)

module OLFramework; end

Olaf = OLFramework

module OLFramework
  module Thread
    def self.new(*args, &block)
      begin
        ::Thread.new(*args, &block)
      rescue
        STDERR.puts "Thread raised and will die: #{$!.message}!"
        STDERR.puts $!.backtrace.join("\n")
      end
    end

    # Several modules inside Olaf are having trouble with the whole
    # ::Thread thing to scope to global.  Let's patch that.
    def self.current
      ::Thread.current
    end
  end

  @@resources ||= Hash.new { |h, k| h[k] = Hash.new }
  @@settings ||= nil  # Create, but with no value yet

  class << self
    def current_request_stack
      ::Thread.current[:ol_current_req_stack]
    end

    def current_request_stack=(st)
      ::Thread.current[:ol_current_req_stack] = st
    end

    def last_request
      current_request_stack ||= []
      current_request_stack[-1]
    end
  end

  RESOURCE_KEYS = [ :name, :description, :controller,
                    :manager, :service, :url, :authenticator,
                    :root, :nodoc ]

  # "data" should be a hash with the following possible keys:
  #
  #   :name          resource name, used for URL mapping  (required)
  #   :description   for swagger-ui
  #   :controller    controller instance
  #   :manager       manager class
  #   :service       service class
  #   :root          root for finding files, including docs and gemspecs
  #   :nodoc         do not include in Swagger documentation
  #   :url           URL prefix for the remote service
  #
  # A resource must have a name and at least one of: controller, service
  # or URL.  A controller gives a simple Rack resource to include
  # locally.  A service gives a full OnLive service, running locally.
  # A URL says how to get to a server or service running remotely.
  #
  # If both service and URL are specified, this gives an OnLive service,
  # but running in another process.
  #
  def self.add_resource(data)
    bad_keys = data.keys - RESOURCE_KEYS
    unless bad_keys.empty?
      raise RuntimeError, "Resource with unknown keys: #{bad_keys.inspect}!"
    end

    data = data.dup  # Don't change original, or let our copy be changed later
    name = data[:name]

    unless @@resources[name].empty?
      raise RuntimeError, "Duplicate resource #{name} was registered!"
    end
    @@resources[name] = data

    unless data[:controller] || data[:service] || data[:url]
      raise RuntimeError, "Service with no implementation was registered!"
    end

    if data[:service] && !data[:controller]
      # Using a service?  Map to an actual Rack app.
      data[:controller] = data[:service].application
    end

    if data[:authenticator] && data[:controller].respond_to?(:"authenticator=")
      data[:controller].authenticator = data[:authenticator]
    end

    unless data[:root]
      env_root = ENV["#{name.gsub("-", "_").upcase}_ROOT"]
      data[:root] = env_root || Dir.pwd
    end

    puts "Registering resource #{data.inspect}"
  end

  def self.resources
    @@resources
  end

  def self.settings
    # Create or refresh settings
    if @@settings
      @@settings.refresh  # Check file mtime
    else
      # Locate JSON file for settings
      filename = ENV['OLAF_SETTINGS']
      filename ||= File.join(File.dirname(__FILE__), "..", "settings", "default.json")

      @@settings = OLFramework::Settings.new
      @@settings.register "tweak", :from_file => filename, :read_only => true
    end
    @@settings
  end

  #
  # This will return a settings object which cannot change, suitable
  # for use over a request timeframe.  You don't want anything
  # changing under this request, even if a new request would get
  # different settings when it started.
  #
  # Basically, we return frozen objects intact and dup non-frozen
  # arrays and hashes.
  #
  def self.settings_for_request(from_settings = self.settings)
    return from_settings if from_settings.frozen?

    if from_settings.is_a? Hash
      return Hash[from_settings.flat_map { |k, v| [k, settings_for_request(v)]}]
    end

    if from_settings.is_a? Array
      return from_settings.map { |v| v }
    end

    from_settings
  end
end

require 'olaf/settings'
require 'olaf/model'
require 'olaf/controller'
require 'olaf/extensions/rack_request'
require 'olaf/rack_helpers'
require 'olaf/errors'

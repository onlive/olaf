# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

# Common controller for the "/" route in all services
require "json"
require "olaf/controller"

module OLFramework
  class RootController < Controller
    set :public_folder, Proc.new { File.join(settings.frame_root, "public") }

    get "/swagger-ui/" do
      logger.debug "Swagger public folder: #{settings.public_folder}"
      redirect "/swagger-ui/index.html"
    end

    get "/statusz/" do
      statusz_file = File.join(settings.root, "statusz.html")
      File.file?(statusz_file) ? send_file(statusz_file) : "No HTML deploy data."
    end

    get "/api-docs.json" do
      content_type "application/json"

      spec = {
        "apiVersion" => "0.1",
        "swaggerVersion" => "1.1",
        "basePath" => "http://#{request.host}:#{request.port}/",
        "apis" => [],
      }

      OLFramework::resources.each do |name, data|
        next if data[:url]    # Only local
        next if data[:nodoc]  # Only if not marked "nodoc"
        spec["apis"] << {
          "path" => "/api-docs.json/#{name}",
          "description" => data[:description],
        }
      end

      JSON.pretty_generate spec
    end

    get "/api-docs.json/:resource" do
      content_type "application/json"

      rsc = OLFramework::resources[params[:resource]]
      if ENV['AUTO_SWAGGER'] && rsc[:service]
        swagger = rsc[:service].swagger_hash(rsc[:name])
        return JSON.pretty_generate swagger
      end

      # We're going to match on resource name, but plurality
      # and dash/underscore can vary.  D'oh!  This is a
      # horrible hack for our current temporary case.
      prefix = params[:resource].split(/-|_/)[0].downcase
      prefix = prefix[0..-2] if prefix[-1] == "s"

      resource = OLFramework::resources[params[:resource]]
      dir = File.join(resource[:root], "api-docs")
      files = Dir["#{dir}/#{prefix}*.json"]
      halt(404) if files.empty?
      File.read(files.first)
    end
  end
end # OLFramework

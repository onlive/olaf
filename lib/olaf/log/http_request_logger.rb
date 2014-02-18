# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'rack/commonlogger'

module Olaf

  # Logger which mimics Rack::CommonLogger but outputs nicely formatted Json
  class HttpRequestLogger < Rack::CommonLogger

    def initialize(app, logger=nil)
      @app = app
      @logger = logger
    end

    private

    # I just copied logic from CommonLogger
    def log(env, status, header, began_at)
      now = Time.now
      length = extract_content_length(header)

      data =
      {
          :remote_ip => env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "?",
          :remote_user => env["REMOTE_USER"] || "",
          :http_method => env["REQUEST_METHOD"],
          :path => env["PATH_INFO"],
          :query => env["QUERY_STRING"].empty? ? "" : "?"+env["QUERY_STRING"],
          :http_version => env["HTTP_VERSION"],
          :http_status => status.to_s[0..3],
          :content_length => length,
          :duration => now - began_at
      }

      logger = @logger || env['rack.errors']
      #logger.write data
    end

    def extract_content_length(headers)
      value = headers['Content-Length'] or return 0
      value.to_s == '0' ? 0 : value
    end
  end
end

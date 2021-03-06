# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
require 'olaf/extensions/uuid'
require 'olaf/http'


module Olaf
  class RequestGuidGenerator

    def initialize(app)
      @app = app
    end

    def call(env)
      if env[ Olaf::Http::CGI_REQUEST_GUID_HEADER ].nil?
        env[ Olaf::Http::CGI_REQUEST_GUID_HEADER ] = UUIDTools::UUID.random_create.to_s
      end
      @app.call(env)
    end

  end
end

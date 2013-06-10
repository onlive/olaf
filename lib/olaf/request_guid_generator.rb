require 'olaf/extensions/uuid'
require 'olaf/http'


module OLFramework
  class RequestGuidGenerator

    def initialize(app)
      @app = app
    end

    def call(env)
      if env[ OLFramework::Http::CGI_REQUEST_GUID_HEADER ].nil?
        env[ OLFramework::Http::CGI_REQUEST_GUID_HEADER ] = UUIDTools::UUID.random_create.to_s
      end
      @app.call(env)
    end

  end
end

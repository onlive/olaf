# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'olaf/http'

module Rack
  class Request

    def header(name)
      mod_name = name.gsub("-", "_").upcase
      self.env["HTTP_#{mod_name}"]
    end

    def guid
      self.env[ OLFramework::Http::CGI_REQUEST_GUID_HEADER ]
    end

    def api_key
      self.env[ OLFramework::Http::CGI_API_KEY_HEADER ]
    end

    def tenant_id
      self.env["HTTP_OLTENANTID"]
    end

  end
end

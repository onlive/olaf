# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
module OLFramework
  module Http
    OK                    = 200
    CREATED               = 201
    NO_CONTENT            = 204

    BAD_REQUEST           = 400
    UNAUTHORIZED          = 401
    FORBIDDEN             = 403
    NOT_FOUND             = 404

    INTERNAL_SERVER_ERROR = 500

    # See http://rack.rubyforge.org/doc/SPEC.html
    # See https://tools.ietf.org/html/rfc3875#section-4.1.18
    REQUEST_GUID_HEADER    = 'OL-Request-Guid'
    CGI_REQUEST_GUID_HEADER = 'HTTP_OL_REQUEST_GUID'

    AUTH_TOKEN_HEADER    = 'OL-Auth-Token'
    CGI_AUTH_TOKEN_HEADER = 'HTTP_OL_AUTH_TOKEN'

    API_KEY_HEADER    = 'OL-Api-Key'
    CGI_API_KEY_HEADER = 'HTTP_OL_API_KEY'

    TENANT_ID_HEADER    = 'OL-Tenant-Id'
    CGI_TENANT_ID_HEADER = 'HTTP_OL_TENANT_ID'
  end
end

require 'logger'

module OLFramework
  # Super-verbose logger which logs the entire request (query, headers, return body, etc)
  class FullRequestLogger
    def initialize(app, max_len = 512)
      @app = app
      @max_len = max_len
    end

    def request_headers(env)
      if env['request.headers']
        return env['request.headers']
      end
      hh = env.select {|k,v| k.start_with? 'HTTP_'}
      env['request.headers'] = hh
    end

    def call(env)
      #puts env
      env['rack.logger'].debug "REQUEST BEGIN Method: #{env['REQUEST_METHOD']} Headers: #{request_headers(env).to_s[0..@max_len]} Body: #{env['rack.input'].string.dump[0..@max_len]}"
      status, headers, body = @app.call(env)
      env['rack.logger'].debug("REQUEST END   Status: #{status} Headers: #{headers.to_s.dump[0..@max_len]} Body: #{body.to_s[0..@max_len]}")
      [status, headers, body]
    end
  end
end

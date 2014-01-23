# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'log4r'

module OLFramework

  # Rack::Logger replacement which uses our logger
  class RackLogger

    def initialize(app, level = Log4r::INFO)
      @app, @level = app, level
    end

    def call(env)
      # TODO: should use shared instance, construction cost is not cheap
      logger = Log4r::Logger.new('Whats my name', @level)
      # TODO: figure out outputter?
      #logger = Log4r::Logger.new(env['rack.errors'])

      env['rack.logger'] = logger
      @app.call(env)
    end
  end

end

require 'logger'

module OLFramework
  class TestLogger
    def initialize(app, level = ::Logger::INFO)
      @app, @level = app, level
    end

    def call(env)
      logger = ::Logger.new(STDOUT)
      logger.level = @level

      env['rack.logger'] = logger
      @app.call(env)
    end
  end
end

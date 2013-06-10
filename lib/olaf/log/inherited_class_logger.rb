# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'logger'

module OLFramework

  # Declare per-class logger in this class and all inherited classes
  module InheritedClassLogger
    def self.included(other)
      @logger =  Logger.new(STDOUT)
      @logger.level = Logger::DEBUG

      other.instance_variable_set("@logger", @logger)
      other.class_eval do
        class << self
          attr_reader :logger
        end

        # This method will be called by Service:do_setup
        def self.logger_helper_inherited(subclass)
          # TODO: set log4r logger name to #{subclass}
          logger =  Logger.new(STDOUT)
          logger.level = Logger::DEBUG
          subclass.instance_variable_set("@logger", logger)
        end
      end
    end

    # Support inheritance: propagate class instance variable to the derived
    def self.inherited(subclass)
      # TODO: set log4r logger name to #{subclass}
      logger =  Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      subclass.instance_variable_set("@logger", logger)
    end
  end

end

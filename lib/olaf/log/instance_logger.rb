# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

module OLFramework

  # Include to get per-instance logger
  module InstanceLogger
    # TODO: switch to log4r
    @@logger =  Logger.new(STDOUT)
    @@logger.level = Logger::DEBUG

    def logger
      @@logger
    end
  end

end

# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

module Olaf

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

# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'log4r'

module OLFramework

  # Rack::Logger replacement which uses our logger
  class Logger < Log4r::Logger

    def initialize(_fullname, _level=nil, _additive=true, _trace=false)
      super
      # TODO: now need to figure out how to redefine methods with extra data parameter
    end

  end

end

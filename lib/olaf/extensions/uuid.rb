# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
require 'uuidtools'

module UUIDTools
  class UUID
    def as_json(*args)
      self.to_s.as_json(*args)
    end
  end
end
# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

module Olaf
  class ReturnValue
    None = nil
  end
end

module Sinatra
  class Response
    def return_value(val=nil)
      if val
        @return_val = val
      elsif @return_val
        @return_val
      else
        Olaf::ReturnValue::None
      end
    end
  end
end

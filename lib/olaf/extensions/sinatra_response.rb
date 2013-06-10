# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

module OLFramework
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
        OLFramework::ReturnValue::None
      end
    end
  end
end

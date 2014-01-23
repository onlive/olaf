# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

class Exception
  def to_ol_hash
    if ["development", "test"].include? ENV['RACK_ENV']
      {
        :class => self.class,
        :message => message,
        :backtrace => backtrace
      }
    else
      {
        :class => self.class,
        :message => message
      }
    end
  end
end

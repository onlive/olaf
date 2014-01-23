# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
class String
  # Lifted from here: http://stackoverflow.com/a/1302183/284853
  # Looks overly complicated, should switch to active record
  def to_slug
    #strip the string
    ret = self.strip

    #blow away apostrophes
    ret.gsub! /['`]/,""

    # @ --> at, and & --> and
    ret.gsub! /\s*@\s*/, " at "
    ret.gsub! /\s*&\s*/, " and "

    #replace all non alphanumeric, underscore or periods with underscore
    ret.gsub! /\s*[^A-Za-z0-9\.\-]\s*/, '-'

    #convert double underscores to single
    ret.gsub! /_+/,"-"

    #strip off leading/trailing underscore
    ret.gsub! /\A[_\.]+|[_\.]+\z/,""

    ret
  end
end

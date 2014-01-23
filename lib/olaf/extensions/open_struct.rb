# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

class OpenStruct
  def to_h_recursive
    ret = to_h
    ret.each do |k,v|
      if v.is_a?(OpenStruct)
        ret[k] = v.to_h_recursive
      end
    end
    ret
  end

  alias :to_hash :to_h_recursive
end
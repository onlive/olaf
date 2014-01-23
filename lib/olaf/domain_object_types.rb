# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'olaf/errors'
require 'olaf/service_helpers'

module OLFramework
  class Json
    def self.type_check_against_ol_value(value)
      if value.is_a?(Hash)
        return value
      end

      if value.is_a?(String)
        begin
          JSON.parse(value)
        rescue => e
          raise OLFramework::ParamTypeError.new(:message=>"#{value} is not valid Json.")
        end
      else
        raise OLFramework::ParamTypeError.new(:message=>"#{value} cannot be Json because it is not a string.")
      end

      return value
    end
  end
end

module UUIDTools
class UUID
  def self.type_check_against_ol_value(value)
    if value.is_a?(String)
      begin
        UUIDTools::UUID.parse(value)
      rescue => e
        raise OLFramework::ParamTypeError.new(:message=>"#{value} is not a valid UUID.")
      end
    else
      raise OLFramework::ParamTypeError.new(:message=>"#{value.class} cannot be a UUID because it is not a string.")
    end

    return value
  end
end
end

class DateTime
  def self.type_check_against_ol_value(value)
    if value.is_a?(String)
      begin
        DateTime.parse(value)
      rescue => e
        raise OLFramework::ParamTypeError.new(:message=>"#{value} is not a valid DateTime.")
      end
    else
      raise OLFramework::ParamTypeError.new(:message=>"#{value.class} cannot be a DateTime because it is not a string.")
    end

    return value
  end
end

# TODO: remove this once we fix up return types; we need this because we do type-checking on the return type bodies, which
# sucks.
class Symbol
  def self.type_check_against_ol_value(value)
    if !value.is_a?(String)
      raise OLFramework::ParamTypeError.new(:message=>"#{value.class} cannot be a Symbol because it is not a string.")
    end
    return value
  end
end


class Fixnum
  def self.type_check_against_ol_value(value)
    if value.is_a?(String)
      raise OLFramework::ParamTypeError.new(:message=>"#{value} is not a valid Fixnum.") if value.to_i == 0 and value != "0"
    else
      raise OLFramework::ParamTypeError.new(:message=>"#{value.class} cannot be a Fixnum because it is not a string.")
    end

    return value
  end
end
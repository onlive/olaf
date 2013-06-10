# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'active_support/core_ext/string/inflections'

class Hash
  #take keys of hash and transform those to a symbols
  def self.convert_keys_to_symbols(val)
    return val unless val.is_a?(Hash)
    val.inject({}) do |memo,(k,v)|
      if k.respond_to?(:to_sym)
        memo[k.to_sym] = Hash.convert_keys_to_symbols(v)
        memo
      else
        memo[k] = Hash.convert_keys_to_symbols(v)
        memo
      end
    end
  end

  def convert_keys_to_symbols
    Hash.convert_keys_to_symbols(self)
  end

  #
  # Hash#slice takes a list or array of arguments,
  # and returns a sub-hash with only those keys
  # from the original hash.
  #
  # @example { :a => 1, :b => 2 }.slice(:a)      # { :a => 1 }
  # @example { :a => 1, :b => 2 }.slice(:a, :b)  # { :a => 1, :b => 2 }
  # @example { :a => 1, :b => 2 }.slice(:c)      # { }
  # @example { :a => 1, :b => 2 }.slice(:a, :c)  # { :a => 1 }
  #
  def slice(*list)
    items = list.flatten.flat_map { |i| self[i] ? [i, self[i]] : [] }
    Hash[*items]
  end

  # Converts hash keys to camel case or snake case
  def camelize(first_letter = :lower)
    hash = {}
    self.each do |k,v|
      symbol = k.is_a?(Symbol)
      new_key = k.to_s.camelize(first_letter)
      hash[symbol ? new_key.to_sym : new_key] = v.is_a?(Hash) ? v.camelize(first_letter) : v
    end
    hash
  end

  def underscore()
    hash = {}
    self.each do |k,v|
      symbol = k.is_a?(Symbol)
      new_key = k.to_s.underscore
      hash[symbol ? new_key.to_sym : new_key] = v.is_a?(Hash) ? v.underscore() : v
    end
    hash
  end
end

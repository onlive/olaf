# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

require 'active_support/core_ext/string/inflections'

class Hash
  def self.map_keys(val, &block)
    return val unless val.is_a?(Hash)
    val.inject({}) do |memo,(k,v)|
      memo[block.call(k)] = Hash.map_keys(v, &block)
      memo
    end
  end

  # take keys of hash and transform those to symbols
  def self.convert_keys_to_symbols(val)
    map_keys(val) { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
  end

  # take keys of hash and transform those to strings
  def self.convert_keys_to_strings(val)
    map_keys(val) { |k| k.respond_to?(:to_s) ? k.to_s : k }
  end

  def convert_keys_to_symbols
    Hash.convert_keys_to_symbols(self)
  end

  def convert_keys_to_strings
    Hash.convert_keys_to_strings(self)
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

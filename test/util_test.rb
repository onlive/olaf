# Copyright (C) 2013 OL2, inc.  All Rights Reserved.

require 'minitest/autorun'
require 'olaf/extensions/hash'

class TestHashExtensions < MiniTest::Unit::TestCase
  def test_slice
    assert_equal({}, { :a => 1, :b => 2 }.slice(:c))
    assert_equal({ :a => 1 }, { :a => 1, :b => 2 }.slice(:a))
    assert_equal({ :a => 1 }, { :a => 1, :b => 2 }.slice(:a, :c))
    assert_equal({ :a => 1 }, { :a => 1, :b => 2 }.slice([:a, :c]))
    assert_equal({ :a => 1, :b => 2 }, { :a => 1, :b => 2 }.slice([:a, :b]))
  end

  def test_convert_keys
    assert_equal({:a => 1, :b => 2}, {"a" => 1, :b =>2}.convert_keys_to_symbols)
    assert_equal({"a" => 1, "b" => 2}, {"a" => 1, :b =>2}.convert_keys_to_strings)
  end
end

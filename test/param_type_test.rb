require 'minitest/autorun'

require 'olaf/service'

# These tests check type-checking, used by API contract validation of
# various kinds.

class TestParamTypes < MiniTest::Unit::TestCase
  include Olaf::ServiceHelpers
  include Olaf::TestHelpers

  Required = Olaf::Required

  def test_simple_params
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value Fixnum, "bob"
    end

    assert_equal 7, check_type_against_value(Fixnum, 7)
    assert_equal "bob", check_type_against_value(String, "bob")
  end

  def test_array_params
    # Scalar type and array value should raise
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value Fixnum, [7]
    end

    # Array type and scalar value should raise
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value [ Fixnum ], 7
    end

    assert_equal [7], check_type_against_value([Fixnum], [7])
    assert_equal [[7]], check_type_against_value([[Fixnum]], [[7]])
  end

  def test_hash_params
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value Hash, 7
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value({}, 7)
    end

    assert_equal({ :name => "bob", :desc => ["tall", "dark", "handsome"] },
      check_type_against_value(
        { :name => String, :desc => [String], :yes => String },
        { :name => "bob", :desc => ["tall", "dark", "handsome"] }))
  end

  def test_required_params
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(Required, nil)
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(Required[String], nil)
    end
    assert_equal "bob", check_type_against_value(Required[String], "bob")

    assert_equal({ :name => "bob", :desc => "tall" },
      check_type_against_value(
        { :name => String, :desc => Required[String], :yes => String },
        { :name => "bob", :desc => "tall" }))
  end

  class HashClassTest
    attr_accessor :goodbye
    attr_accessor :farewell
  end

  def test_hash_against_class_param
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, {"parting_is_such_sweet_sorrow"=>true})
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, {""=>""})
    end

    assert_equal({}, check_type_against_value(HashClassTest, {}))
    assert_equal(nil, check_type_against_value(HashClassTest, nil))
    # strings should get converted into the appropriate symbols
    assert_equal({"goodbye"=>"hello hello"}, check_type_against_value(HashClassTest, {"goodbye"=>"hello hello"}))
    # but symbols shouldn't fail either.
    assert_equal({:goodbye=>"hello hello"}, check_type_against_value(HashClassTest, {:goodbye=>"hello hello"}))
    # check multiple elements
    assert_equal({:goodbye=>"au revoir", :farewell=>"adieu"}, check_type_against_value(HashClassTest, {:goodbye=>"au revoir", :farewell=>"adieu"}))
  end

  def test_hash_array_against_class_param
    # Array does not match single element
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, [{}])
    end
    # Single element doesn't match array
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value([HashClassTest], {})
    end
    # Actually look for type inside array
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value([HashClassTest], [{"There is no goodbye"=>false}])
    end
    assert_equal([{}], check_type_against_value([HashClassTest], [{}]))
    assert_equal([{}, {}], check_type_against_value([HashClassTest], [{}, {}]))
    assert_equal([{:goodbye=>"tschuess"}], check_type_against_value([HashClassTest], [{:goodbye=>"tschuess"}]))
    assert_equal([{:goodbye=>"tschuess"}, {:farewell=>"auf wiedersehen"}], check_type_against_value([HashClassTest], [{:goodbye=>"tschuess"}, {:farewell=>"auf wiedersehen"}]))
  end

  def test_hash_string_against_class_param
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, "[[[badJson*")
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, "not even an attempt")
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value(HashClassTest, [{}].to_json)
    end

    assert_equal({}.to_json, check_type_against_value(HashClassTest, {}.to_json))
    assert_equal({"goodbye"=>"this should work"}.to_json, check_type_against_value(HashClassTest, {"goodbye"=>"this should work"}.to_json))
  end

  def test_hash_array_string_against_class_param
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value([HashClassTest], {}.to_json)
    end
    assert_raises(Olaf::ParamTypeError) do
      check_type_against_value([HashClassTest], [{"There is no goodbye"=>false}].to_json)
    end
    assert_equal([{}].to_json, check_type_against_value([HashClassTest], [{}].to_json))
    assert_equal([{}, {}].to_json, check_type_against_value([HashClassTest], [{}, {}].to_json))
    assert_equal([{:farewell=>"welfare"}].to_json, check_type_against_value([HashClassTest], [{:farewell=>"welfare"}].to_json))
    assert_equal([{:farewell=>"welfare"}, {:goodbye=>"byegood"}].to_json, check_type_against_value([HashClassTest], [{:farewell=>"welfare"}, {:goodbye=>"byegood"}].to_json))
  end

end

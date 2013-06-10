# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'minitest/autorun'
require 'olaf/logger_helpers'
require 'olaf/domain_object'
require 'date'
require 'olaf/extensions/uuid'

# These tests check the base implementation of our framework domain objects.

class TestDomainObject < MiniTest::Unit::TestCase

  include OLFramework::LoggerHelpers

  class TestObject < OLFramework::DomainObject
    field :id, String, :create => false, :update => false
    field :sausages, Fixnum
    field :bacon, Hash, :update => false
    field :deliciousness, Fixnum, :readonly => true, :private => true
  end

  class NestedTestObject < OLFramework::DomainObject
    field :bun, String
    field :hotdog, TestObject
  end

  def test_field_definitions
    test_obj = TestObject.new({})
    assert test_obj.respond_to?(:sausages), "TestObject does not have sausages getter"
    assert test_obj.respond_to?("sausages=", "TestObject does not have sausages setter")
  end

  def test_field_get_and_set
    test_obj = TestObject.new({:id => "123", :sausages => 5})
    assert_equal test_obj.sausages, 5, "Did not get value of 5 for sausages"
    test_obj.sausages = 6
    assert_equal test_obj.sausages, 6, "Did not get value of 6 for sausages"
  end

  def test_readonly_field
    test_obj = TestObject.new({:id => "123", :sausages => 5, :deliciousness => 11})
    assert_raises OLFramework::FieldUpdateError do
      test_obj.deliciousness = 0
    end
  end

  def test_invalid_field_option
    assert_raises OLFramework::InvalidDomainObjectOption do
      eval('class BadClass < OLFramework::DomainObject; field :bad_field, String, :bad_option => "foo"; end;')
    end
  end

  def test_private_field
    test_obj = TestObject.new({:id => "123", :sausages => 5, :deliciousness => 11})
    externalized = test_obj.to_external_hash
    assert(!externalized.has_key?(:deliciousness))
  end

  def test_check_hash_fields_basic
    test_hash = {:id=>"Booga", :sausages=>3, :bacon => {}}
    assert_equal(test_hash, TestObject.check_hash_against_domain_object(test_hash, {:ignore_unknown_fields => false}))
  end

  def test_check_hash_fields_with_ignore
    test_hash = {:id=>"Ooga", :frisee => "a pound"}
    assert_equal({:id=>"Ooga"}, TestObject.check_hash_against_domain_object(test_hash, {:ignore_unknown_fields => true}))
  end

  def test_check_hash_fields_type
    assert_raises(OLFramework::ParamTypeError) do
      TestObject.check_hash_against_domain_object({:id=>3}, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestObject.check_hash_against_domain_object({:sausages=>"SomeString"}, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestObject.check_hash_against_domain_object({:bacon=>[]}, {:ignore_unknown_fields => false})
    end
  end

  def test_nested_object_type
    assert_raises(OLFramework::ParamTypeError) do
      NestedTestObject.check_hash_against_domain_object({:hotdog=>3}, {:ignore_unknown_fields => false})
    end

    contained_object_hash = {:id=>"HotLink", :bacon=>{:fried => "yes", :crispy => "yes"}}

    contained_object = TestObject.new(contained_object_hash)
    assert_equal({:hotdog => contained_object},
                 NestedTestObject.check_hash_against_domain_object({:hotdog => contained_object}, {:ignore_unknown_fields => false}))

    # test case in which the contained_object is a hash itself
    assert_equal({:hotdog => contained_object_hash},
                 NestedTestObject.check_hash_against_domain_object({:hotdog => contained_object_hash}, {:ignore_unknown_fields => false}))

    # test checking inside hash
    nested_object_hash = {:bun=>"abcdef", :hotdog =>
        {:vegan_bacon => {:fried => "yes", :crispy => "yes", :tastes_like_bacon=>false}}}

    assert_raises(OLFramework::ParamTypeError) do
      NestedTestObject.check_hash_against_domain_object(nested_object_hash, {:ignore_unknown_fields => false})
    end

    # now make sure that the ignore flag is passed through
    assert_equal({:bun=>"abcdef", :hotdog => {}},
        NestedTestObject.check_hash_against_domain_object(nested_object_hash, {:ignore_unknown_fields => true}))
  end

  class TestJsonType < OLFramework::DomainObject
    field :json_blob, OLFramework::Json
  end

  def test_json_type
    blob = {"id"=>"bananarama", "starfruit"=>[2, 3], "fruitbat" => { "silly" => "goose" } }.to_json
    assert_equal({:json_blob => blob},
                 TestJsonType.check_hash_against_domain_object({:json_blob => blob}, {:ignore_unknown_fields => false}))
    assert_equal({:json_blob => {}.to_json},
                 TestJsonType.check_hash_against_domain_object({:json_blob => {}.to_json}, {:ignore_unknown_fields => false}))

    assert_raises(OLFramework::ParamTypeError) do
      TestJsonType.check_hash_against_domain_object({:json_blob => "malformed json"}, {:ignore_unknown_fields => true})
    end

    assert_raises(OLFramework::ParamTypeError) do
      TestJsonType.check_hash_against_domain_object({:json_blob=>[]}, {:ignore_unknown_fields => true})
    end

    assert_raises(OLFramework::ParamTypeError) do
      TestJsonType.check_hash_against_domain_object({:json_blob => "{{{}}".to_json}, {:ignore_unknown_fields => true})
    end
  end

  class TestUUIDType < OLFramework::DomainObject
    field :uuid_blob, UUIDTools::UUID
  end

  def test_uuid_type
    test_uuid = "e0d87b29-fa2a-4a59-810b-a2a1ab2d38ba"

    assert_equal({:uuid_blob => test_uuid},
                 TestUUIDType.check_hash_against_domain_object({:uuid_blob => test_uuid}, {:ignore_unknown_fields => false}))
    test_actual_uuid = UUIDTools::UUID.random_create
    assert_equal({:uuid_blob => test_actual_uuid},
                 TestUUIDType.check_hash_against_domain_object({:uuid_blob => test_actual_uuid}, {:ignore_unknown_fields => false}))

    assert_raises(OLFramework::ParamTypeError) do
      TestUUIDType.check_hash_against_domain_object({:uuid_blob => "e0d87b29"}, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestUUIDType.check_hash_against_domain_object({:uuid_blob => {} }, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestUUIDType.check_hash_against_domain_object({:uuid_blob => ""}, {:ignore_unknown_fields => false})
    end

  end

  class TestDateTimeType < OLFramework::DomainObject
    field :date, DateTime
  end

  def test_datetime_type
    test_date_time = "2013-04-23T13:01:39-07:00"

    assert_equal({:date => test_date_time},
                 TestDateTimeType.check_hash_against_domain_object({:date => test_date_time}, {:ignore_unknown_fields => false}))
    actual_date_time = DateTime.now()
    assert_equal({:date => actual_date_time},
                 TestDateTimeType.check_hash_against_domain_object({:date => actual_date_time}, {:ignore_unknown_fields => false}))

    assert_raises(OLFramework::ParamTypeError) do
      TestDateTimeType.check_hash_against_domain_object({:date => "e0d87b29"}, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestDateTimeType.check_hash_against_domain_object({:date => {} }, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestDateTimeType.check_hash_against_domain_object({:date => ""}, {:ignore_unknown_fields => false})
    end
  end

  class TestFixnumType < OLFramework::DomainObject
    field :number, Fixnum
  end

  def test_fixnum_type
    test_fixnum = "12345"

    assert_equal({:number => test_fixnum},
                 TestFixnumType.check_hash_against_domain_object({:number => test_fixnum}, {:ignore_unknown_fields => false}))

    assert_equal({:number => "0"},
                 TestFixnumType.check_hash_against_domain_object({:number => "0"}, {:ignore_unknown_fields => false}))

    actual_date_time = 12345
    assert_equal({:number => actual_date_time},
                 TestFixnumType.check_hash_against_domain_object({:number => actual_date_time}, {:ignore_unknown_fields => false}))

    assert_raises(OLFramework::ParamTypeError) do
      TestFixnumType.check_hash_against_domain_object({:number => "hello"}, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestFixnumType.check_hash_against_domain_object({:number => {} }, {:ignore_unknown_fields => false})
    end
    assert_raises(OLFramework::ParamTypeError) do
      TestFixnumType.check_hash_against_domain_object({:number => ""}, {:ignore_unknown_fields => false})
    end
  end

  def test_hash_for_create
    test_obj = TestObject.new({:id=>"12345", :sausages=>5, :bacon=>{}})
    assert_equal({:sausages=>5, :bacon=>{}}, test_obj.hash_for_create)
  end

  def test_hash_for_update
    test_obj = TestObject.new({:id=>"12345", :sausages=>5, :bacon=>{}})
    assert_equal({:sausages=>5}, test_obj.hash_for_update)
  end

  def test_from_external_hash
    test_obj = TestObject.from_external_hash({:id=>"hi", :sausages=>1000})
    assert_equal(TestObject.new({:id=>"hi", :sausages=>1000}), test_obj)
  end

  def test_from_external_hash_fails
    assert_equal(nil, TestObject.from_external_hash(3))
  end

  def test_from_external_hash_array
    test_obj = TestObject.from_external_hash([{:id=>"hi", :sausages=>1000}, {:id=>"bye", :bacon=>{}}], true)
    assert_equal([TestObject.new({:id=>"hi", :sausages=>1000}), TestObject.new({:id=>"bye", :bacon=>{}})], test_obj)
  end

  def test_from_external_hash_array_fails
    assert_equal(nil, TestObject.from_external_hash({:id=>"hi"}, true))
  end

  def test_from_external_hash_array_nested_object_fail
    assert_equal(nil, TestObject.from_external_hash([{:id=>"hi"}, 3], true))
  end


end

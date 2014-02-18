# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'minitest/autorun'
require 'rack/test'
require 'olaf'
require 'olaf/service'
require 'olaf/domain_object'

class TestObject < Olaf::DomainObject
  def self.print_name(obj)
    puts "Hi my name is #{obj.name}"
  end

  field :name, String
  field :size, Fixnum
  field :description, String
end

class TestService < Olaf::Service
  service_name "TestService"

  route_name :create_test_object
  desc "Create a test object"
  param :data, TestObject, "Body data", :type => :body
  errors 400 => "Invalid request parameters",
         503 => "Internal server problem"
  return_type TestObject

  post "/" do
    test_obj = params[:data]
    raise RuntimeError, "Did not get TestObject in params" unless test_obj.is_a? TestObject
    TestObject.print_name(test_obj)
    body(test_obj.to_json)
  end

  route_name :update_test_object
  desc "Update test object"
  param :object_name, String, "Object name"
  param :data, TestObject, "Body data", :type => :body
  errors 400 => "Invalid request parameters",
         503 => "Internal server problem"
  return_type TestObject
  put "/:object_name" do
    test_obj = params[:data]
    raise RuntimeError, "Body params did not get properly deleted" if params["name"]
    raise RuntimeError, "Did not get :object_name param" unless params[:object_name]
    raise RuntimeError, "Did not get TestObject in params" unless test_obj.is_a? TestObject
  end
end

class TestInputParams < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestService.application
  end

  def setup
    @test_obj = {
        "name" => "object",
        "size" => "5",
        "description" => "test object"
    }
    @test_obj_extras = {
        "bad_field" => "booga"
    }.merge(@test_obj)
  end

  def test_post_success
    post "/", @test_obj do |response|
      assert response.ok?, "Create test object failed"
      assert_equal response.body, @test_obj.to_json, "Did not get @test_obj back"
    end
  end

  # Test that this still works if the body is not at the top-level
  def test_post_success_with_param
    post "/", {:data => @test_obj} do |response|
      assert response.ok?, "Create test object failed"
      assert_equal response.body, @test_obj.to_json, "Did not get @test_obj back"
    end
  end

  def test_post_success_extra_params
    post "/", @test_obj_extras do |response|
      assert response.ok?, "Create test object failed"
      assert_equal response.body, @test_obj.to_json, "Did not get @test_obj back"
    end
  end

  def test_post_failure
    # Can't think of a better way to make sure we don't get into the body of the route
    # since the ParamTypeError gets caught and logged by the Controller
    dont_allow(TestObject).print_name

    post "/", {"size" => "asdf"}
  end

  # Test the put case because it's a slightly different code path in our overridden process_route
  def test_put_success
    put "/blah", @test_obj do |response|
      assert response.ok?, "Update test object failed"
    end
  end
end

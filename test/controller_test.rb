require 'minitest/autorun'
require 'rack/test'
require 'olaf'

# I don't know how to test OLFramework::Controller without running a Rack server
# So I'm going to use TestController and URI handlers.
class TestController < OLFramework::Controller
  include OLFramework::TestHelpers

  get '/test-paging' do
    content_type :json

    limit = params['limit']
    offset = params['offset']
    if limit.kind_of?(Integer) && offset.kind_of?(Integer) && limit == 10 && offset == 23
      halt 200
    elsif limit.nil? and offset.nil?
      halt 200
    end
    halt 400
  end

  get '/' do
    "Hello"
  end

  get '/throw/ArgumentError' do
    raise ::ArgumentError, "Test Passed"
  end

  get '/throw/ObjectNotFound' do
    raise DataMapper::ObjectNotFoundError, "Test Passed"
  end

  get '/throw/RestClientException' do
    raise RestClient::Exception.new(nil, 500), "Test Passed"
  end

  get '/throw/FrameworkException' do
    raise OLFramework::Error.new(:error_code => 1000, :http_response_code => 500, :request_guid => "7d6b0dd4-a83f-11e2-a237-000a27020050"), "Test Passed"
  end

  get '/throw/UnknownException' do
    raise RuntimeError, "Test Passed"
  end
end

class TestFrameworkController < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestController
  end

  def test_basic
    get '/'
    assert last_response.ok?
    assert_equal last_response.body, 'Hello'
  end

  def test_options
    options '/'
    assert last_response.ok?
  end

  def test_pagination_query_params
    get '/test-paging?limit=10&offset=23'
    assert last_response.ok?
  end

  def test_bad_pagination_query_params
    get '/test-paging?limit=puppy&offset=corn'
    assert last_response.ok?
  end

  def test_argument_error_returns_400
    get '/throw/ArgumentError'
    assert_equal 400, last_response.status
  end

  def test_object_not_found_returns_404
    get '/throw/ObjectNotFound'
    assert_equal 404, last_response.status
  end

  def test_rest_client_exception
    get '/throw/RestClientException'
    assert_equal last_response.status, 500
  end

  def test_framework_exception
    get 'throw/FrameworkException'
    assert_equal last_response.status, 500
  end

  def test_unknown_exception
    get 'throw/UnknownException'
    assert_equal last_response.status, 500
  end
end

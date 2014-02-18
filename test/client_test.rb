require 'minitest/autorun'

require 'olaf'
require 'olaf/service'
require 'olaf/http'
require 'olaf/extensions/uuid'

class TestService < Olaf::Service
  service_name "TestService"

  route_name :hello_world
  get "/helloworld" do |params|
  end

  route_name :post_hello_stranger
  post "/hello/:stranger" do |params|
  end

  route_name :hello_stranger
  get "/hello/:stranger" do |params|
  end


end

Olaf::add_resource(:name => "TestService",
                          :service => TestService,
                          :url => "http://test.domain.com")

FAKE_REQUEST_GUID = "7d6b0dd4-a83f-11e2-a237-000a27020050"

class TestServiceClient < MiniTest::Unit::TestCase

  # TODO: we must be able to auto-generate client_route_name here...
  def mock_restclient_request(method, url, params_or_payload, client_route_name,
                              headers = { :accept => :json }, status = 200,
                              result = "{}", raise_exc = false)
    args = {
      :method => method,
      :url => url,
      :headers => {Olaf::Http::REQUEST_GUID_HEADER => FAKE_REQUEST_GUID}.merge(headers)
    }

    stub(UUIDTools::UUID).random_create { FAKE_REQUEST_GUID }

    if Olaf::ServiceClient::HTTP_VERBS_WITH_PAYLOAD.include?(method)
      args[:payload] = params_or_payload
    else
      args[:headers].merge!(:params => params_or_payload)
    end

    fake_response = OpenStruct.new :code => status, :headers => headers,
                                   :body => result
    mock(fake_response).return!.with_any_args
    mock(RestClient::Request).execute(args).yields(fake_response, nil, nil) do
      if raise_exc
        raise Olaf::Error.new( :http_response_code => 500, :message => "Failed!", :error_code => 1002, :request_guid => "7d6b0dd4-a83f-11e2-a237-000a27020050")
      end
      result
    end
  end

  def test_hello_world
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/helloworld",
                            { "foo" => "bar" }, :hello_world, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.hello_world!("foo" => "bar"))
  end

  def test_hello_world_symbols
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/helloworld",
                            { "foo" => "bar" }, :hello_world, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.hello_world!(:foo => "bar"))
  end

  def test_hello_stranger
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            {}, :hello_stranger, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.hello_stranger!("stranger" => "bobo"))
  end

  def test_hello_stranger_raiseless
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            {}, :hello_stranger, { :accept => :json }, 500, "{:error => 'Yes'}")

    val, ctx = TestService.client.hello_stranger({"stranger" => "bobo"}, :raise => false)
    assert_equal ctx[:status], 500
  end

  def test_hello_stranger_bang_version
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            {}, :hello_stranger, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.hello_stranger!("stranger" => "bobo"))
  end

  def test_hello_stranger_with_exception
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            {}, :hello_stranger, { :accept => :json }, 200, "{}", true)  # raise

    e = assert_raises ::Olaf::Error do
      TestService.client.hello_stranger!("stranger" => "bobo")
    end
  end

  def test_hello_stranger_symbols
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            {}, :hello_stranger, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.hello_stranger!(:stranger => "bobo"))
  end

  def test_post_hello_stranger
    mock_restclient_request(:post,
                            "http://test.domain.com/TestService/hello/sam",
                            { "param1" => "foo" }, :post_hello_stranger, { :accept => :json }, 200, "{}")

    assert_equal({}, TestService.client.post_hello_stranger!(:stranger => "sam", :param1 => "foo"))
  end

  def test_hello_stranger_headers
    mock_restclient_request(:get,
                            "http://test.domain.com/TestService/hello/bobo",
                            { }, :hello_stranger, { :accept => :nothing }, 200, "{}")

    assert_equal({}, TestService.client.hello_stranger!({"stranger" => "bobo"}, {:headers => {:accept => :nothing}}))
  end

  def test_param_exception
    # RestClient allows specifying "params" in the headers, but we don't.
    assert_raises RuntimeError do
      TestService.client.hello_stranger({"stranger" => "bobo"}, :headers => { "params" => { "a" => "b" } })
    end
  end


end

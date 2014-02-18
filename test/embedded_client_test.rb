require 'minitest/autorun'
require 'rack/test'

require 'olaf'
require 'olaf/service'

class FirstEmbeddedService < Olaf::Service
  service_name "FirstEmbeddedService"

  route_name :hello_embedded
  get "/helloembedded" do
    "Ok"
  end

  route_name :hello_stranger
  get "/hello/:stranger" do
    "Hello, #{params[:stranger]}"
  end

  route_name :post_hello
  post "/helloembedded" do
    "params: #{params.inspect}"
  end

  route_name :throw_an_error
  get "/throw-me-an-error" do
    puts "Throwing OLArgumentError"
    raise ::Olaf::OLArgumentError
  end

end

class SecondEmbeddedService < Olaf::Service
  service_name "SecondEmbeddedService"

  route_name :call_through
  get "/call_through" do
    FirstEmbeddedService.client.hello_embedded!({})
  end

  param :stranger, String, "Who to say hi to"
  route_name :call_through_arg
  get "/call_through_arg" do
    FirstEmbeddedService.client.hello_stranger!(:stranger => params[:stranger])
  end

  route_name :call_through_raiseless
  get "/call_through_raiseless" do
    val, ctx = FirstEmbeddedService.client.hello_embedded!({}, :raise => false)
    val
  end
end

# No URL - they're embedded in the same process.
Olaf::add_resource(:name => "FirstEmbeddedService",
                          :service => FirstEmbeddedService)
Olaf::add_resource(:name => "SecondEmbeddedService",
                          :service => SecondEmbeddedService)

class TestEmbeddedServiceClient < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    SecondEmbeddedService.application
  end

  def test_embedded_basic
    get "/call_through"
    assert_equal ["Ok"], [last_response.body].flatten
  end

  def test_embedded_with_arg
    get "/call_through_arg", :stranger => "Bob"
    assert_equal ["Hello, Bob"], [last_response.body].flatten
  end

  def test_embedded_raiseless
    get "/call_through_raiseless"
    assert_equal ["Ok"], [last_response.body].flatten
  end

  def test_client_rethrows
    # RestClient allows specifying "params" in the headers, but we don't.
    e = assert_raises ::Olaf::Error do
      FirstEmbeddedService.client.throw_an_error!( {} )
    end

    assert_equal e.error_code, 1006
    #assert_equal e.error_code, 1006
  end
end

require 'minitest/autorun'
require 'olaf/errors'

class TestFrameworkError < MiniTest::Unit::TestCase


  def test_serialization
    e = {
        :error_code => 10000,
        :http_response_code => 400,
        :request_guid => "7d6b0dd4-a83f-11e2-a237-000a27020050",
    }

    hash =  Olaf::Error.new(e).to_ol_hash

    assert !hash.has_key?(:http_response_code), "Must not have http response in the hash"
    assert hash[:error_code], e[:error_code]
    assert hash[:request_guid], e[:request_guid]
    assert hash.has_key?(:message)
    assert hash.has_key?(:class)
    assert hash.has_key?(:backtrace)
  end

  TestError = Olaf::define_error(1000, 400)

  def test_error_definition
    e = TestError.new(:request_guid => "7d6b0dd4-a83f-11e2-a237-000a27020050")

    assert_equal 1000, e.error_code
    assert_equal 400, e.http_code
  end

end

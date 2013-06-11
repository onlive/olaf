require 'minitest/autorun'

require 'olaf/log/json_formatter'

class TestJsonFormatter < MiniTest::Unit::TestCase

  def test_json_formatter
    #trouble = Log4r::Logger.new('log4r')
    #trouble.add Log4r::Outputter.stdout

    logger = Log4r::Logger.new("test")
    out = StringIO.new
    logger.add Log4r::IOOutputter.new( "stdout", out, :formatter => Olaf::JsonFormatter )

    Log4r::NDC.push("test_ndc")
    Log4r::MDC.put('mdc1', 'value1')

    logger.info "test message"
    result = JSON.parse(out.string)
    assert_equal result['level'], 'INFO'
    assert_equal result['logger'], 'test'
    assert_equal result['message'], 'test message'
    assert_equal result['pid'], Process.pid.to_s
    assert_equal result['thread'], Thread.current.to_s
    assert_equal result['NDC'], 'test_ndc'
    assert_equal result['mdc1'], 'value1'
    puts out.string

    out.string = ""

    logger.info :message => "Message", :some_field => "Other"
    result = JSON.parse(out.string)
    assert_equal result['level'], 'INFO'
    assert_equal result['message'], 'Message'
    assert_equal result['some_field'], 'Other'
    puts out.string

    #logger.error "error"
  end

end

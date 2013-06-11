require 'minitest/autorun'

require 'olaf/log/json_formatter'

class TestJsonFormatter < MiniTest::Unit::TestCase

  def test_json_formatter
    #trouble = Log4r::Logger.new('log4r')
    #trouble.add Log4r::Outputter.stdout

    logger = Log4r::Logger.new("test")
    logger.add Log4r::StdoutOutputter.new( "stdout", :formatter => Olaf::JsonFormatter )

    #logger.info "test"
    #logger.error "error"
  end

end

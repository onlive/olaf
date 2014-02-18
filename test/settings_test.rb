require 'minitest/autorun'

require 'olaf/settings'

class TestBasicSettings < MiniTest::Unit::TestCase
  def setup
    @settings = Olaf::Settings.new
  end

  def test_read_write_setting
    @settings.register "bobo"

    @settings["bobo"] = "human"
    assert_equal "human", @settings["bobo"]
    assert_equal "human", @settings[:bobo]
  end

  def test_read_only_setting
    @settings.register "jojo", :read_only => true, :value => 7

    assert_equal 7, @settings["jojo"]

    assert_raises Olaf::SettingNoUpdate do
      @settings["jojo"] = 5
    end
  end

  def test_from_json_file
    file_contents = '{ "a": 1, "b": 2, "c": 3 }'
    mock(File).read(anything) { file_contents }.times(2)
    file_time = Time.now
    mock(File).mtime(anything) { file_time }.times(2)

    @settings.register "jojo", :read_only => true, :from_file => "file.json"

    assert_equal 1, @settings[:jojo]['a']

    # "can't modify frozen Hash"
    assert_raises RuntimeError do
      @settings["jojo"]["a"] = 5
    end

    file_contents = '{ "a": 4, "b": 5, "c": 6 }'
    file_time = Time.now  # update mocked file

    @settings.refresh
    assert_equal 4, @settings["jojo"]['a']
  end

  def test_from_yaml_file
    file_contents = "---\nc: 5\nd: 7\n"
    mock(File).read(anything) { file_contents }
    mock(File).mtime(anything) { Time.now }

    @settings.register "jojo", :read_only => true, :from_file => "file.yaml"

    assert_equal 5, @settings[:jojo]['c']
  end

  def test_remove_setting
    @settings.register "bobo"

    @settings[:bobo] = "human"
    assert_equal "human", @settings["bobo"]
    assert_equal "human", @settings[:bobo]

    @settings.unregister "bobo"

    assert_raises Olaf::SettingNotFound do
      @settings["bobo"]
    end
  end
end

require 'ci/reporter/rake/minitest'
require 'rake/testtask'

OL_TEST_HELPER = File.join(File.dirname(__FILE__), "..", "test_helpers")
Rake::TestTask.new do |t|
  t.libs << "test"
  t.ruby_opts.concat ["-r", OL_TEST_HELPER]  # Helper FIRST
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end


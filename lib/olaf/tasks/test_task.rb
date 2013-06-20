# Copyright (C) 2013 OL2, inc.  All Rights Reserved.

require 'ci/reporter/rake/minitest'
require 'rake/testtask'

OL_TEST_HELPER = File.join(File.dirname(__FILE__), "..", "test_helpers")
OL_INTEGRATION_HELPER = File.join(File.dirname(__FILE__), "..", "test_int_helpers")
Rake::TestTask.new do |t|
  t.libs << "test"
  t.ruby_opts.concat ["-r", OL_TEST_HELPER]  # Helper FIRST
  t.test_files = FileList['test/**/*_test.rb'] - FileList['test/integration/*_test.rb']
  t.verbose = true
end

Rake::TestTask.new("test:integration") do |t|
  t.libs << "test"
  t.ruby_opts.concat ["-r", OL_INTEGRATION_HELPER]  # Helper FIRST
  t.test_files = FileList['test/integration/*_test.rb']
  t.verbose = true
end

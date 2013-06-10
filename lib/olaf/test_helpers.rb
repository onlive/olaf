# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

# Must set the environment here, not in the included hook
STDERR.puts "Setting RACK_ENV => test"
ENV['RACK_ENV'] = 'test'

# SimpleCov MUST be first.
if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-rcov'
  class SimpleCov::Formatter::MergedFormatter
    def format(result)
       SimpleCov::Formatter::HTMLFormatter.new.format(result)
       SimpleCov::Formatter::RcovFormatter.new.format(result)
    end
  end
  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
  SimpleCov.start do
    add_filter "/vendor/"
    add_filter "/test/"
    # Single shared coverage dir
    root File.join(File.dirname(__FILE__), "..", "..", "..")
    coverage_dir "coverage"
    command_name "MiniTest in #{Dir.getwd}"

    merge_timeout 1800
  end

  STDERR.puts "Started SimpleCov due to COVERAGE environment variable."
end

require 'dm-core'
require 'dm-migrations'
require 'mysql2'

module OLFramework
  module TestHelpers

    def self.included(base)
      ENV['RACK_ENV'] = 'test'  # Redundant, see comment above

      db_type = ENV['OL_DB_SETUP'] || 'sqlite'
      if db_type  =~ /sqlite/
        db_config = "sqlite3::memory:"
      else
        user = ENV['OL_SQL_USER'] || 'root'
        password = ENV['OL_SQL_PASSWORD'] || 'wrux9bax'

        client = Mysql2::Client.new(:host => "localhost", :username => user, :password=>password)
        results = client.query('drop database if exists ol_unit_test')
        results = client.query('create database if not exists ol_unit_test')
        db_config = "mysql://#{user}:#{password}@localhost/ol_unit_test"
      end
      STDERR.puts "DataMapper: test using #{db_config}"
      DataMapper.setup :default, db_config

      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize
      DataMapper.auto_migrate!
    end
  end
end

# Always load local copy of ol_application *first*
# ????????????
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

require "rr"
require "minitest/unit"
require "minitest/pride"

class MiniTest::Unit::TestCase
  include RR::Adapters::MiniTest
end

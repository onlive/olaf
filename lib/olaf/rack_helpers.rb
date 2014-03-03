# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
# Utility functions designed to be called from config.ru

require "olaf"
require "olaf/model"
require "olaf/root_controller"
require "mysql2"
require "yaml"

module Olaf
  module RackHelpers
    def self.setup   (config = {})
      if !@olf_orm_initialized
        config[:db] ||= ENV['OL_DB_SETUP'] || 'sqlite'
        config[:user] ||= ENV['OL_SQL_USER'] || 'root'
        config[:password] ||= ENV['OL_SQL_PASSWORD'] || 'wrux9bax'

        Olaf::RackHelpers::setup_datamapper(config)
        @olf_orm_initialized = true
      else
         STDERR.puts('ORM already intiialized')
      end
    end

    def self.app
      url_map = {
        "/" => Olaf::RootController
      }
      Olaf::resources.each do |name, data|
        next if data[:url]  # Only local
        if data[:controller]
          url_map["/#{name}"] = data[:controller]
          data[:controller].authenticator = data[:authenticator] if data[:authenticator]
        end
      end

      Rack::URLMap.new(url_map)
    end

    def self.setup_datamapper(config)
      if ENV['RACK_ENV'] == 'test'
        DataMapper.setup :default, "sqlite3::memory:"
      else
        if config[:db] =~ /sqlite/
          db_config = "sqlite://#{Dir.pwd}/database.db"
        elsif config[:db] =~ /mysql/

          db_name = File.basename(Dir.pwd)
          db_config = "mysql://#{config[:user]}:#{config[:password]}@localhost/#{db_name}"

          client = Mysql2::Client.new(:host => "localhost", :username => config[:user], :password=>config[:password])
          client.query("create database if not exists #{db_name}") # if wrong pw will throw error
        else
          raise "Database configuration is not specified."
        end

        STDERR.puts "DataMapper: using #{db_config} #{db_name}"
        DataMapper.setup :default, db_config
      end
      DataMapper::Model.raise_on_save_failure = true

      DataMapper.finalize

      if ENV['RACK_ENV'] == 'test'
        DataMapper.auto_migrate!
      else
        DataMapper.auto_upgrade!
      end
    end

  end # RackHelpers
end # Olaf

# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
# Utility functions designed to be called from config.ru

require "olaf"
require "olaf/model"
require "olaf/root_controller"
require "mysql2"
require "yaml"


module Olaf
  module RackHelpers
    def self.setup   (config = {})  # e.g. {:db=>"mysql", :orm=>'ar'}
      # Make sure datamapper and/or activerecord only get set up once
      if !@olf_orm_initialized
        config[:db] ||= ENV['OL_DB_SETUP'] || 'sqlite'
        config[:user] ||= ENV['OL_SQL_USER'] || 'root'
        config[:password] ||= ENV['OL_SQL_PASSWORD'] || 'wrux9bax'

        if config[:orm] == "ar"
          # set up both for now
          Olaf::RackHelpers::setup_activerecord(config)
          Olaf::RackHelpers::setup_datamapper(config)
        else
          Olaf::RackHelpers::setup_datamapper(config)
        end
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
        # TODO: will eventually want to switch tests to mysql as well.
        DataMapper.setup :default, "sqlite3::memory:"
      else
        if config[:db] =~ /sqlite/
          db_config = "sqlite://#{Dir.pwd}/database.db"
        else

          db_name = File.basename(Dir.pwd)
          db_config = "mysql://#{config[:user]}:#{config[:password]}@localhost/#{db_name}"

          client = Mysql2::Client.new(:host => "localhost", :username => config[:user], :password=>config[:password])
          client.query("create database if not exists #{db_name}") # if wrong pw will throw error
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

    def self.setup_activerecord(config)
      require "active_record"

      if config[:db] =~ /sqlite/
          db_config = {:adapter => 'sqlite3', :database=>"#{Dir.pwd}/database.db"}
      else

        db_name = File.basename(Dir.pwd)

        filename = ENV['OL_SQL_SETTINGS']
        filename ||= File.join(File.dirname(__FILE__), "..", "..", "settings", "database.yml")
          # TODO: better way to access settings directory
        dbconfigs = YAML::load(File.open(filename))
        dbconfig = dbconfigs[ENV['RACK_ENV']] || {}
        dbconfig[:database] = db_name

        ActiveRecord::Base.establish_connection(dbconfig)
        #ActiveRecord::Base.logger = logger.new(STDERR) # should this be logger or something else?
      end
      STDERR.puts "ActiveRecord: using #{db_config} #{db_name}"

    end

  end # RackHelpers
end # Olaf

begin
  require "./metadata.rb"
rescue LoadError
  OL_GEM_VERSION ||= "0.1.dev"
end

Gem::Specification.new do |s|
  s.name = "olaf"
  s.version = OL_GEM_VERSION
  s.summary = "OnLive Ruby REST framework"
  s.authors = ["noah.gibbs@onlive.com", "alex.snyatkov@onlive.com", "peter.lai@onlive.com", "shasha.chu@onlive.com"]
  s.email         = ["onplatform@onlive.com"]
  s.description   = s.summary
  s.homepage      = ""

  s.files   = `git ls-files`.split($/)

  # DataMapper & related
  s.add_runtime_dependency "datamapper"
  s.add_runtime_dependency "dm-migrations"
  s.add_runtime_dependency "dm-serializer"
  s.add_runtime_dependency "dm-sqlite-adapter"
  s.add_runtime_dependency "dm-mysql-adapter"
  s.add_runtime_dependency "dm-timestamps"
  s.add_runtime_dependency "dm-types"
  s.add_runtime_dependency "dm-validations"
  s.add_runtime_dependency "mysql2"
  s.add_runtime_dependency "cassandra"

  # ActiveRecord
  s.add_runtime_dependency "activerecord", "~>3.2.0"

  # Sinatra & related
  s.add_runtime_dependency "rack"
  s.add_runtime_dependency "rack-multipart_related"
  s.add_runtime_dependency "rack-parser"
  s.add_runtime_dependency "rack-test"
  s.add_runtime_dependency "sinatra"
  s.add_runtime_dependency "sinatra-contrib"
  s.add_runtime_dependency "thin"
  s.add_runtime_dependency "statusz"

  # General
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "fast_open_struct"
  s.add_runtime_dependency "log4r"

  # Development-only
  s.add_development_dependency "rake"
  s.add_development_dependency "rr"  , ">1.0.5"
  s.add_development_dependency "minitest", "<5.0"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "simplecov-rcov"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "ci_reporter"
  s.add_development_dependency "debugger"
  s.add_development_dependency "yard"
  s.add_development_dependency "redcarpet", "<2.0"  # Is 2.0 YARD-compatible yet?
  s.add_development_dependency "ruby_git_hooks"
  s.add_development_dependency "trollop"
  s.add_development_dependency "nodule"
end

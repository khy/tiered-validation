$: << File.expand_path("#{File.dirname(__FILE__)}/../lib")

if version = ENV['ACTIVE_RECORD_VERSION']
  require 'rubygems'
  gem 'activerecord', version
end

require 'activerecord'
require File.expand_path(File.dirname(__FILE__) + '/../init')

db_location = "#{File.dirname(__FILE__)}/db"
db_config = {"adapter"=>"sqlite3", "database"=>"#{db_location}/test.db"}
ActiveRecord::Base.establish_connection(db_config)  
ActiveRecord::Base.logger = Logger.new(File.open('/dev/null', 'w'))

unless File.file?("#{db_location}/test.db")
  ActiveRecord::Migrator.migrate("#{db_location}/migrate")
end

require 'active_record'
$: << File.expand_path("#{File.dirname(__FILE__)}/../lib")
require File.dirname(__FILE__) + '/../init'

db_location = "#{File.dirname(__FILE__)}/db"
db_config = {"adapter"=>"sqlite3", "database"=>"#{db_location}/test.db"}
ActiveRecord::Base.establish_connection(db_config)  
ActiveRecord::Base.logger = Logger.new(File.open('/dev/null', 'w'))

unless File.file?("#{db_location}/test.db")
  ActiveRecord::Migrator.migrate("#{db_location}/migrate")
end
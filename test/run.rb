#!/usr/bin/env ruby

require './lib/webink/database.rb'
require './lib/webink/model.rb'
require './lib/webink/controller.rb'
require './lib/webink/beauty.rb'
require './lib/webink/sql_adapter.rb'
require './lib/sqlite3_adapter.rb'
require 'test/unit'

config = {
  :db_type => "sqlite3",
  :db_server => "./test.sqlite"
}
model_classes = Array.new

Dir.chdir(File.dirname(__FILE__))

require "#{config[:db_type]}"

models = Dir.new "./models"
models.each do |model|
  load "#{models.path}/#{model}" if model =~ /\.rb$/
  model_classes.push Ink::Model.classname($1) if model =~ /^(.*)\.rb$/
end

begin
  Ink::Database.create config
  db = Ink::Database.database
  db.tables.each do |t|
    db.query "DROP TABLE #{t}"
  end
  model_classes.each do |m|
    m.create.each do |exec|
      begin
        puts exec
        db.query exec
      rescue => ex
        puts ex
      end
    end
  end

  tests = Dir.new "./"
  tests.each do |t|
    load "#{tests.path}/#{t}" if t =~ /^tc_.*\.rb$/
  end
rescue Exception => bang
  puts "SQLError: #{bang}."
  puts bang.backtrace.join("\n")
end

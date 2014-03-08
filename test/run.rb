#!/usr/bin/env ruby

gem 'minitest'

require 'webink/r'
require './lib/webink/database.rb'
require './lib/webink/model.rb'
require './lib/webink/controller.rb'
require './lib/webink/beauty.rb'
require './lib/webink/sql_adapter.rb'
require './lib/sqlite3_adapter.rb'
require './lib/webink/r.rb'
require 'minitest/autorun'
require 'minitest/spec'

config = {
  :db_type => "sqlite3",
  :db_server => "./test.sqlite"
}

Dir.chdir(File.dirname(__FILE__))

require "#{config[:db_type]}"

model_classes = Dir.open("./models").reduce([]) do |acc, model|
  load "./models/#{model}" if model =~ /\.rb$/
  acc << Ink::Model.classname($1) if model =~ /^(.*)\.rb$/
  acc
end

begin
  Ink::Database.create(config)
  db = Ink::Database.database
  db.tables.each do |t|
    db.query("DROP TABLE #{t}")
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

  Dir.open("./").each do |t|
    load "./#{t}" if t =~ /^tc_.*\.rb$/
  end
rescue Exception => bang
  puts "SQLError: #{bang}."
  puts bang.backtrace.join("\n")
end

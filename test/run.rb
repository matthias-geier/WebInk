#!/usr/bin/env ruby

gem 'minitest'

require 'webink/r'
require './lib/webink/database.rb'
require './lib/webink/associations.rb'
require './lib/webink/model.rb'
require './lib/webink/controller.rb'
require './lib/webink/beauty.rb'
require './lib/webink/sql_adapter.rb'
require './lib/sqlite3_adapter.rb'
require './lib/webink/extensions/r.rb'
require './lib/webink/extensions/string.rb'
require 'minitest/autorun'

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

  describe Ink::Model do
    before do
      Ink::Database.database.query("BEGIN TRANSACTION")
    end

    after do
      Ink::Database.database.query("ROLLBACK")
    end

    Dir.open("./").each do |t|
      load "./#{t}" if t =~ /_test\.rb$/
    end
  end
rescue Exception => bang
  puts "SQLError: #{bang}."
  puts bang.backtrace.join("\n")
end

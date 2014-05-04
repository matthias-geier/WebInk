#!/usr/bin/env ruby

gem 'minitest'

require 'webink/r'
require 'sqlite3'
require '../lib/webink/database.rb'
require '../lib/webink/association/associations.rb'
require '../lib/webink/association/one_one.rb'
require '../lib/webink/association/many_one.rb'
require '../lib/webink/association/one_many.rb'
require '../lib/webink/association/many_many.rb'
require '../lib/webink/model.rb'
require '../lib/webink/controller.rb'
require '../lib/webink/beauty.rb'
require '../lib/webink/sql_adapter.rb'
require '../lib/sqlite3_adapter.rb'
require '../lib/webink/extensions/r.rb'
require '../lib/webink/extensions/string.rb'
require '../lib/webink/database/util.rb'
require 'minitest/autorun'

Dir.chdir(File.dirname(__FILE__))

beauty = Ink::Beauty.new
config = beauty.load_config
model_classes = Dir.new("./models").select{ |m| m =~ /\.rb$/ }.map do |m|
  load("./models/#{m}")
  $1.camelize.constantize if m =~ /^(.*)\.rb$/
end
Ink::Database::Util.build_database(config[:test_db], model_classes, true)

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

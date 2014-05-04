
module Ink
  class Database
    module Util
      def self.build_all_databases(config, model_classes, drop_first=false)
        config.keys.select{ |k| k.to_s =~ /_db$/ }.each do |db|
          self.build_database(config[db], model_classes, drop_first)
        end
      end

      def self.build_database(config, model_classes, drop_first=false)
        Ink::Database.create(config)
        db = Ink::Database.database
        db_tables = db.tables

        if drop_first
          puts "Dropping old tables..."
          db_tables.each do |t|
            puts "...#{t}"
            db.query "DROP TABLE #{db.wrap_character}#{t}#{db.wrap_character};"
          end
        end

        puts "Creating new tables..."
        model_classes.each do |m|
          next unless m < Ink::Model
          puts "...for class: #{m.name}:"
          c = m.create
          puts c
          c.each do |exec|
            begin
              db.query exec
            rescue => ex
              puts ex
            end
          end
        end

        if File.exist?('db_seed.rb')
          load('db_seed.rb')
        end
      rescue Exception => bang
        puts "SQLError: #{bang}."
        puts bang.backtrace.join("\n")
      end
    end
  end
end

module Ink

  # = Database class
  #
  # == Config
  #
  # Currently there are two types of databases supported, MySQL and
  # SQLite3. Either way, you need to specify them in a config-file
  # that is located inside the web project folder.
  #
  # Sample config for MySQL:
  #   config = {
  #     :production        => true,
  #     :app_db => {
  #       :db_type           => "mysql",
  #       :db_user           => "yourusername",
  #       :db_pass           => "yourpassword",
  #       :db_database       => "yourdatabase",
  #       :db_server         => "localhost"
  #     },
  #     :test_db => {
  #       :db_type           => "mysql",
  #       :db_user           => "yourusername",
  #       :db_pass           => "yourpassword",
  #       :db_database       => "yourtestdatabase",
  #       :db_server         => "localhost"
  #     }
  #   }
  #
  # Sample config for SQLite3:
  #   config = {
  #     :production        => true,
  #     :app_db => {
  #       :db_type           => "sqlite3",
  #       :db_server         => "/full/path/to/database.sqlite",
  #     },
  #     :test_db => {
  #       :db_type           => "sqlite3",
  #       :db_server         => "/full/path/to/test_database.sqlite",
  #     }
  #   }
  #
  # == Adapters
  #
  # Generally before using the database, a fitting adapter needs to be
  # loaded which will host the necessary methods to query the database.
  #
  # The SqlAdapter is an abstract class shipped with webink that is
  # inherited in Sqlite3Adapter and MysqlAdapter. Any custom adapters
  # can be easily built in a similar manner. More information can be
  # found in the doc of SqlAdapter
  #
  # This means, all database does essentially, is being an interface
  # to all methods offered by the adapters. Method documentation is copied
  # over to the SqlAdapter for convenience.
  #
  # == Usage
  #
  # Create an Ink::Database instance with the self.create class method.
  # Now it can be accessed via the public class variable 'database'.
  # Once that is done, can use it to execute various SQL statements
  # to gather data.
  #
  #   Ink::Database.database.query "SELECT * FROM x;"
  #
  # This is the most basic query, it returns an Array of results,
  # and each element contains a Hash of column_name => column_entry.
  #
  #   Ink::Database.database.query("SELECT * FROM x;", Array){ |itm, k, v|
  #     itm.push v
  #   }
  #
  # The query method has a second parameter "type" which defaults to Hash.
  # This is the class instance created in the resultset array (i.e.
  # query returns [ type, type, type,...]).
  # A block allows you to assign the k (column name) and v (value) to itm
  # (a type.new taken from the second parameter) however you like.
  #
  #   Ink::Database.database.transaction(false) do
  #     Ink::R.update(:foobar).set("ref=24").execute
  #   end
  #
  # Code can be wrapped in a transaction block and therefore be grouped
  # or if require rolled back, like in the example above. Giving the
  # call to #transaction false will automatically roll back the transaction
  # and giving it true will attempt to commit.
  #
  # Please close the dbinstance once you are done. This is automatically
  # inserted in the init.rb of a project.
  #
  # == Convenience methods
  #
  #   Database.format_date(Time.now)
  #
  # This will return a date in the form of 2012-11-20 10:00:02 and takes a Time
  # instance.
  #
  #
  #
  class Database
    private_class_method :new
    @@database = nil

    # Private Constructor
    #
    # Uses the config parameter to create a database
    # connection, and will throw an error, if that is not
    # possible.
    # [param config:] Hash of config parameters
    def initialize(config)
      klass = Ink.const_get("#{config[:db_type].capitalize}Adapter")
      if klass.is_a?(Class)
        @db_class = klass
        @db = klass.new(config)
      else
        raise ArgumentError.new("Database undefined.")
      end
    end

    # Class method
    #
    # Instanciates a new Database if none is found
    # [param config:] Hash of config parameters
    def self.create(config)
      @@database = new(config) if not @@database
    end

    # Class method
    #
    # Removes an instanciated Database
    def self.drop
      @@database = nil if @@database
    end

    # Class method
    #
    # Returns the Database instance or raises a Runtime Error
    # [returns:] Database instance
    def self.database
      if @@database
        @@database
      else
        raise RuntimeError.new("No Database found. Create one first")
      end
    end

    # Instance method
    #
    # This will retrieve all tables nested into
    # the connected database.
    # [returns:] Array of tables
    def tables
      @db.tables
    end

    # Instance method
    #
    # Send an SQL query string to the database
    # and retrieve a result set
    # [param query:] SQL query string
    # [returns:] Array of Hashes of column_name => column_entry
    def query(query, type=Hash, &blk)
      @db.query(query, type, &blk)
    end

    # Instance method
    #
    # Closes the database connection, there is no way
    # to reopen without creating a new Ink::Database instance
    def close
      @db.close
      self.class.drop
    end

    # Instance method
    #
    # Attempts to fetch the last inserted primary key
    # [param class_name:] Defines the __table__ name or class
    # [returns:] primary key or nil
    def last_inserted_pk(class_name)
      @db.last_inserted_pk(class_name)
    end

    # Instance method
    #
    # Creates the SQL syntax for the chosen database type
    # to define a primary key, autoincrementing field
    # [returns:] SQL syntax for a primary key field
    def primary_key_autoincrement(pk="id")
      @db.primary_key_autoincrement(pk)
    end

    # Instance method
    #
    # Wraps the block given into a transaction that can be either set
    # to commit or rollback.
    # [param commit:] Commit or rollback; default is commit
    # [param yield:] Any code block that should be wrapped by a transaction
    def transaction(commit=true, &blk)
      @db.transaction(commit, &blk)
    end

    # Instance method
    #
    # Returns the foreign key type of a database. This does not necessarily
    # overlap with the primary key type. i.e. postgres uses SERIAL for
    # auto increments while the type is still INTEGER
    # [returns:] SQL data type as string
    def foreign_key_type
      return @db_class.foreign_key_type
    end

    # Instance method
    #
    # Formats a Time object according to the SQL TimeDate standard
    # [param date:] Time object
    # [returns:] Formatted string
    def format_date(date)
      return @db_class.format_date(date)
    end

    # Instance method
    #
    # [returns:] wrap-character for table names
    def wrap_character
      return @db_class.wrap_character
    end

  end

end

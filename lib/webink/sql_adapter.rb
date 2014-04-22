module Ink

  # = Database Adapter class for SQL-Databases
  #
  # This class should be extended by any implementations of a database
  # adapter. Adapters need to follow a naming convention:
  #
  #   module Ink
  #     class <capitalized_db_gem_name>Adapter
  #     end
  #   end
  #
  # Example:
  #
  #   module Ink
  #     class MysqlAdapater
  #     end
  #   end
  #
  # The database is extracted from the field :db_type in the config passed
  # on to the adapter and also describes the gem name to include.
  #
  # All inheriting classes need to override these methods:
  #   initialize(config)
  #   tables
  #   query(query, type=Hash)
  #   close
  #   primary_key_autoincrement(pk="id")
  #   transaction(commit=true, &blk)
  #
  # == Usage
  #
  # The necessary instance to connect to the database is automatically loaded
  # by Ink::Database. As long as naming conventions are followed, additional
  # modules can be included.
  #
  # == Convenience methods
  #
  # A series of convenience methods are located here instead of Ink::Database
  # for the sole reason that timestamps etc. may differ in various database
  # implementations and being able to override in adapters will help connecting
  # to exactly those databases.
  #
  #
  #
  class SqlAdapter

    # Abstract Constructor
    #
    # Uses the config parameter to create a database
    # connection, and will throw an error, if that is not
    # possible.
    # [param config:] Hash of config parameters
    def initialize(config)
      raise NotImplementedError.new('Override initialize')
    end

    # Abstract Instance method
    #
    # This will retrieve all tables nested into
    # the connected database.
    # [returns:] Array of tables
    def tables
      raise NotImplementedError.new('Override tables')
    end

    # Abstract Instance method
    #
    # Send an SQL query string to the database
    # and retrieve a result set
    # [param query:] SQL query string
    # [returns:] Array of Hashes of column_name => column_entry
    def query(query, type=Hash)
      raise NotImplementedError.new('Override query')
    end

    # Instance method
    #
    # Wraps the block given into a transaction that can be either set
    # to commit or rollback.
    # [param commit:] Commit or rollback; default is commit
    # [param yield:] Any code block that should be wrapped by a transaction
    def transaction(commit=true, &blk)
      raise NotImplementedError.new('Override transaction')
    end

    # Abstract Instance method
    #
    # Closes the database connection, there is no way
    # to reopen without creating a new Ink::Database instance
    def close
      raise NotImplementedError.new('Override close')
    end

    # Abstract Instance method
    #
    # Creates the SQL syntax for the chosen database type
    # to define a primary key, autoincrementing field
    # [returns:] SQL syntax for a primary key field
    def primary_key_autoincrement(pk="id")
      raise NotImplementedError.new('Override primary_key_autoincrement')
    end

    # Class method
    #
    # Returns the foreign key type of a database. This does not necessarily
    # overlap with the primary key type. i.e. postgres uses SERIAL for
    # auto increments while the type is still INTEGER
    # [returns:] SQL data type as string
    def self.foreign_key_type
      return "INTEGER"
    end

    # Class method
    #
    # Formats a Time object according to the SQL TimeDate standard
    # [param date:] Time object
    # [returns:] Formatted string
    def self.format_date(date)
      (date.instance_of? Time) ? date.strftime("%Y-%m-%d %H:%M:%S") : ""
    end

    # Class method
    #
    # Transform a value to sql representative values.
    # This means quotes are escaped, nils are transformed
    # and everything else is quoted.
    # [param value:] Object
    # [returns:] transformed String
    def self.transform_to_sql(value)
      if value.nil?
        "NULL"
      elsif value.is_a? String
        "\'#{value.gsub(/'/, '&#39;')}\'"
      elsif value.is_a? Numeric
        value
      else
        "\'#{value}\'"
      end
    end

    # Class method
    #
    # Transform a value from sql to objects.
    # This means nils, integer, floats and strings
    # are imported correctly.
    # Escaped single quotes are transformed back.
    # [param value:] String
    # [returns:] Object
    def self.transform_from_sql(value)
      if value =~ /^NULL$/
        nil
      elsif value =~ /^\d+$/
        value.to_i
      elsif value =~ /^\d+\.\d+$/
        value.to_f
      elsif value.is_a?(String)
        value.gsub('&#39;', "'")
      else
        value
      end
    end

    # Instance method
    #
    # Attempts to fetch the last inserted primary key
    # [param class_name:] Defines the __table__ name or class
    # [returns:] primary key or nil
    def last_inserted_pk(class_name)
      unless class_name.is_a?(Class)
        class_name = Ink::Model.classname(class_name)
      end
      table_name = class_name.table_name!
      pk_name = class_name.primary_key
      return if table_name.nil? or pk_name.nil?
      response = self.query("SELECT MAX(#{pk_name}) as id FROM #{table_name};")
      return (response.empty?) ? nil : response.first["id"]
    end

    # Class method
    #
    # [returns:] wrap-character for table names
    def self.wrap_character
      return '`'
    end

  end
end

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
  #     :db_type           => "mysql",
  #     :db_user           => "yourusername",
  #     :db_pass           => "yourpassword",
  #     :db_database       => "yourdatabase",
  #     :db_server         => "localhost",
  #   }
  #
  # Sample config for SQLite3:
  #   config = {
  #     :production        => true,
  #     :db_type           => "sqlite3",
  #     :db_server         => "/full/path/to/database.sqlite",
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
  # The following methods are convenience methods to access data for
  # models. As example a model Apple and its n:1 relation to Tree
  # are used. Please note that both class and database table name can
  # be used to call the find and related methods. The table name for
  # Apple would be "apple"; for MyApple would be "my_apple".
  #
  #   Ink::Database.database.find "apple", "WHERE id < 10 GROUP BY color"
  #   => self.query("SELECT * FROM apple WHERE id < 10 GROUP BY color;")
  #
  # This is different from the query method, because it returns an Array
  # of Objects, created by the information stored in the database. So this
  # find() will return you a set of Apple-instances.
  #
  #   Ink::Database.database.find_union "apple", 5, "tree", "AND tree_id>1"
  #
  # find_union allows you to retrieve data through a many_many reference.
  # When you define a many_many relationship, a helper-table is created
  # inside the database, which is apple_tree, in this case. This statement
  # will fetch an Array of all Trees, that connect to the Apple with primary
  # key 5. Notice that the relationship database apple_tree is put together
  # by the alphabetically first, and then second classname. The last quotes
  # allow additional query informations to be passed along (like group by)
  #
  #   Ink::Database.database.find_references Tree, 1, Apple, "AND tree_id>1"
  #
  # find_references is similar to find_union, only that it handles all
  # other relationships. This statement above requires one Tree to have many
  # Apples, so it will return an Array of Apples, all those that belong to
  # the Tree with primary key 1
  #
  #   Ink::Database.database.find_reference Apple, 5, Tree, ""
  #
  # find_reference is essentially equal to find_references, yet it returns
  # one result of a Tree or nil. This is used when Apple-Tree is a many_one
  # or one_one relationship. It saves the need for the result Array from
  # find_references.
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

    # Class method
    #
    # Transform a value to sql representative values.
    # This means quotes are escaped, nils are transformed
    # and everything else is quoted.
    # [param value:] Object
    # [returns:] transformed String
    def self.transform_to_sql(value)
      @db_class.transform_to_sql(value)
    end

    # Class method
    #
    # Transform a value from sql to objects.
    # This means nils, integer, floats and strings
    # are imported correctly.
    # [param value:] String
    # [returns:] Object
    def self.transform_from_sql(value)
      @db_class.transform_from_sql(value)
    end

    # Instance method
    #
    # Send an SQL query string to the database
    # and retrieve a result set
    # [param query:] SQL query string
    # [returns:] Array of Hashes of column_name => column_entry
    def query(query, type=Hash)
      @db.query(query, type)
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
    # Delete something from the database.
    # [param class_name:] Defines the class name or class
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    def remove(class_name, params="")
      @db.remove(class_name, params)
    end

    # Instance method
    #
    # Retrieve class instances, that are loaded with the database result set.
    # [param class_name:] Defines the class name or class which should be
    #                     queried
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    # [returns:] Array of class_name instances from the SQL result set
    def find(class_name, params="")
      @db.find(class_name, params)
    end

    # Instance method
    #
    # Retrieve class2 instances, that are related to the class1 instance with
    # primary key class1_id. This is done via an additional relationship table.
    # Only relevant for many_many relationships.
    # [param class1:] Reference classname or class
    # [param class1_id:] Primary key value of the reference classname
    # [param class2:] Match classname or class
    # [param params:] Additional SQL syntax like GROUP BY (optional)
    # [returns:] Array of class2 instances from the SQL result set
    def find_union(class1, class1_id, class2, params="")
      @db.find_union(class1, class1_id, class2, params)
    end

    # Instance method
    #
    # Retrieve class2 instances, that are related to the class1 instance with
    # primary key class1_id. Not relevant for many_many relationships
    # [param class1:] Reference classname or class
    # [param class1_id:] Primary key value of the reference classname
    # [param class2:] Match classname or class
    # [param params:] Additional SQL syntax like GROUP BY (optional)
    # [returns:] Array of class2 instances from the SQL result set
    def find_references(class1, class1_id, class2, params="")
      @db.find_references(class1, class1_id, class2, params)
    end

    # Instance method
    #
    # Retrieve one class2 instance, that is related to the class1 instance with
    # primary key class1_id. Only relevant for one_one and one_many
    # relationships
    # [param class1:] Reference classname or class
    # [param class1_id:] Primary key value of the reference classname
    # [param class2:] Match classname or class
    # [param params:] Additional SQL syntax like GROUP BY (optional)
    # [returns:] single class2 instance from the SQL result set or nil
    def find_reference(class1, class1_id, class2, params="")
      @db.find_reference(class1, class1_id, class2, params)
    end

    # Instance method
    #
    # This method attempts to remove all existing relationship data
    # of instance with link of type: type. For one_one relationships
    # this works only one way, requiring a second call later on before
    # setting a new value.
    # [param instance:] Instance of a class that refers to an existing database entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    def delete_all_links(instance, link, type)
      @db.delete_all_links(instance, link, type)
    end

    # Instance method
    #
    # Attempt to create links of instance to the data inside value.
    # link is the class of the related data, and type refers to the
    # relationship type of the two. When one tries to insert an array
    # for a x_one relationship, the last entry will be set.
    # [param instance:] Instance of a class that refers to an existing
    #                   database entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    # [param value:] relationship data that was set, either a primary key value,
    #                or an instance, or an array of both
    def create_all_links(instance, link, type, value)
      @db.create_all_links(instance, link, type, value)
    end

    # Instance method
    #
    # Creates a link between instance and a link with primary fk.
    # The relationship between the two is defined by type. one_one
    # relationships are placing an additional call to delete_all_links
    # that will remove conflicts.
    # [param instance:] Instance of a class that refers to an existing database
    #                   entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    # [param value:] primary key of the relationship, that is to be created
    def create_link(instance, link, type, fk)
      @db.create_link(instance, link, type, fk)
    end

    # Class method
    #
    # Formats a Time object according to the SQL TimeDate standard
    # [param date:] Time object
    # [returns:] Formatted string
    def self.format_date(date)
      @db_class.format_date(date)
    end

    def transaction(commit=true, &blk)
      @db.transaction(commit, &blk)
    end

  end

end

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
  #     "escape_post_data"  => false,
  #     "production"        => true,
  #     "db_type"           => "mysql",
  #     "db_user"           => "yourusername",
  #     "db_pass"           => "yourpassword",
  #     "db_database"       => "yourdatabase",
  #     "db_server"         => "localhost",
  #   }
  #
  # Sample config for SQLite3:
  #   config = {
  #     "escape_post_data"  => false,
  #     "production"        => true,
  #     "db_type"           => "sqlite3",
  #     "db_server"         => "/full/path/to/database.sqlite",
  #   }
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
      @type = config["db_type"]
      if @type == "mysql"
        @db = Mysql.real_connect(config["db_server"],config["db_user"],config["db_pass"],config["db_database"])
        @db.reconnect = true
      elsif @type == "sqlite3"
        @db = SQLite3::Database.new(config["db_server"])
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
      (@@database) ? @@database : (raise RuntimeError.new("No Database found. Create one first"))
    end
    
    # Instance method
    # 
    # This will retrieve all tables nested into
    # the connected database.
    # [returns:] Array of tables
    def tables
      result = Array.new
      if @type == "mysql"
        re = @db.query "show tables;"
        re.each do |row|
          row.each do |t|
            result.push t
          end
        end
      elsif @type == "sqlite3"
        re = @db.query "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        re.each do |row|
          row.each do |t|
            result.push t
          end
        end
        re.close
      end
      result
    end
    
    # Instance method
    # 
    # Send an SQL query string to the database
    # and retrieve a result set
    # [param query:] SQL query string
    # [returns:] Array of Hashes of column_name => column_entry
    def query(query)
      result = Array.new
      if @type == "mysql"
        re = @db.method("query").call query
        if re
          re.each_hash do |row|
            result.push Hash.new
            row.each do |k,v|
              if v =~ /^[0-9]+$/
                v = $&.to_i
              elsif v =~ /^[0-9]+\.[0-9]+$/
                v = $&.to_f
              end
              result[result.length-1][k] = v
            end
          end
        end
      elsif @type == "sqlite3"
        re = @db.method("query").call query
        re.each do |row|
          result.push Hash.new
          for i in 0...re.columns.length
            if row[i] =~ /^[0-9]+$/
              row[i] = $&.to_i
            elsif row[i] =~ /^[0-9]+\.[0-9]+$/
              row[i] = $&.to_f
            end
            result[result.length-1][re.columns[i]] = row[i]
          end
        end
        re.close if not re.closed?
      end
      result
    end
    
    # Instance method
    # 
    # Closes the database connection, there is no way
    # to reopen without creating a new Ink::Database instance
    def close
      if @type == "sqlite3" and not @db.closed?
        begin
          @db.close
        rescue SQLite3::BusyException
        end
      elsif @type == "mysql"
        @db.close
      end
      self.class.drop
    end
    
    # Instance method
    # 
    # Attempts to fetch the last inserted primary key
    # [param class_name:] Defines the __table__ name or class
    # [returns:] primary key or nil
    def last_inserted_pk(class_name)
      c = (class_name.is_a? Class) ? class_name : Ink::Model.classname(class_name)
      table_name = c.table_name
      pk_name = c.primary_key[0]
      return if not (table_name and pk_name)
      response = self.query("SELECT MAX(#{pk_name}) as id FROM #{table_name};")
      return (response.length > 0) ? response[0]["id"] : nil
    end
    
    # Instance method
    # 
    # Creates the SQL syntax for the chosen database type
    # to define a primary key, autoincrementing field
    # [returns:] SQL syntax for a primary key field
    def primary_key_autoincrement(pk="id")
      result = Array.new
      if @type == "mysql"
        result = ["`#{pk}`", "INTEGER", "PRIMARY KEY", "AUTO_INCREMENT"]
      elsif @type == "sqlite3"
        result = ["`#{pk}`", "INTEGER", "PRIMARY KEY", "ASC"]
      end
      result
    end
    
    # Instance method
    # 
    # Delete something from the database.
    # [param class_name:] Defines the class name or class
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    def remove(class_name, params="")
      table_name = (class_name.is_a? Class) ? class_name.table_name : Ink::Model.str_to_tablename(class_name)
      return if not table_name
      self.query("DELETE FROM #{table_name} #{params};")
    end
    
    # Instance method
    # 
    # Retrieve class instances, that are loaded with the database result set.
    # [param class_name:] Defines the class name or class which should be queried
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    # [returns:] Array of class_name instances from the SQL result set
    def find(class_name, params="")
      c = (class_name.is_a? Class) ? class_name : Ink::Model.classname(class_name)
      result = Array.new
      table_name = c.table_name
      return result if not table_name
      
      re = self.query("SELECT * FROM #{table_name} #{params};")
      re.each do |entry|
        instance = c.new entry
        result.push instance
      end
      result
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
      c1 = (class1.is_a? Class) ? class1 : Ink::Model.classname(class1)
      c2 = (class2.is_a? Class) ? class2 : Ink::Model.classname(class2)
      result = Array.new
      relationship = nil
      c1.foreign.each do |k,v|
        relationship = v if k.downcase == c2.class_name.downcase
      end
      return result if relationship != "many_many"
      fk1 = c1.foreign_key[0]
      pk2 = c2.primary_key[0]
      fk2 = c2.foreign_key[0]
      tablename1 = c1.table_name
      tablename2 = c2.table_name
      union_class = ((c1.class_name.downcase <=> c2.class_name.downcase) < 0) ? "#{tablename1}_#{tablename2}" : "#{tablename2}_#{tablename1}"
      re = self.query("SELECT #{tablename2}.* FROM #{union_class}, #{tablename2} WHERE #{union_class}.#{fk1} = #{class1_id} AND #{union_class}.#{fk2} = #{tablename2}.#{pk2} #{params};")
      re.each do |entry|
        instance = c2.new entry
        result.push instance
      end
      result
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
      c1 = (class1.is_a? Class) ? class1 : Ink::Model.classname(class1)
      c2 = (class2.is_a? Class) ? class2 : Ink::Model.classname(class2)
      result = Array.new
      relationship = nil
      c1.foreign.each do |k,v|
        relationship = v if k.downcase == c2.class_name.downcase
      end
      return result if relationship == "many_many"
      re = Array.new
      fk1 = c1.foreign_key[0]
      tablename1 = c1.table_name
      tablename2 = c2.table_name
      if ((c1.class_name.downcase <=> c2.class_name.downcase) < 0 and relationship == "one_one") or relationship == "one_many"
        re = self.query "SELECT * FROM #{tablename2} WHERE #{c2.primary_key[0]}=(SELECT #{c2.foreign_key[0]} FROM #{tablename1} WHERE #{c1.primary_key[0]}=#{class1_id});"
      else
        re = self.query "SELECT * FROM #{tablename2} WHERE #{fk1} = #{class1_id} #{params};"
      end
      
      re.each do |entry|
        instance = c2.new entry
        result.push instance
      end
      result
    end
    
    # Instance method
    # 
    # Retrieve one class2 instance, that is related to the class1 instance with
    # primary key class1_id. Only relevant for one_one and one_many relationships
    # [param class1:] Reference classname or class
    # [param class1_id:] Primary key value of the reference classname
    # [param class2:] Match classname or class
    # [param params:] Additional SQL syntax like GROUP BY (optional)
    # [returns:] single class2 instance from the SQL result set or nil
    def find_reference(class1, class1_id, class2, params="")
      result_array = self.find_references class1, class1_id, class2, params
      if result_array.length == 1
        result_array[0]
      else
        nil
      end
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
      if type == "one_one"
        firstclass = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? instance.class : link
        secondclass = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? link : instance.class
        key = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? instance.class.primary_key[0] : instance.class.foreign_key[0]
        value = instance.method(instance.class.primary_key[0]).call
        @db.query "UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key[0]}=NULL WHERE #{key}=#{value};"
      elsif type == "one_many" or type == "many_one"
        firstclass = (type == "one_many") ? instance.class : link
        secondclass = (type == "one_many") ? link : instance.class
        key = (type == "one_many") ? instance.class.primary_key[0] : instance.class.foreign_key[0]
        value = instance.method(instance.class.primary_key[0]).call
        @db.query "UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key[0]}=NULL WHERE #{key}=#{value};"
      elsif type == "many_many"
        tablename1 = instance.class.table_name
        tablename2 = link.table_name
        union_class = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? "#{tablename1}_#{tablename2}" : "#{tablename2}_#{tablename1}"
        value = instance.method(instance.class.primary_key[0]).call
        @db.query "DELETE FROM #{union_class} WHERE #{instance.class.foreign_key[0]}=#{value};"
      end
    end
    
    # Instance method
    # 
    # Attempt to create links of instance to the data inside value.
    # link is the class of the related data, and type refers to the
    # relationship type of the two. When one tries to insert an array
    # for a x_one relationship, the last entry will be set.
    # [param instance:] Instance of a class that refers to an existing database entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    # [param value:] relationship data that was set, either a primary key value, or an instance, or an array of both
    def create_all_links(instance, link, type, value)
      to_add = Array.new
      if value.is_a? Array
        value.each do |v|
          if v.instance_of? link
            to_add.push(v.method(link.primary_key[0]).call)
          else
            to_add.push v
          end
        end
      elsif value.instance_of? link
        to_add.push(value.method(link.primary_key[0]).call)
      else
        to_add.push value
      end
      to_add.each do |fk|
        self.create_link instance, link, type, fk
      end
    end
    
    # Instance method
    # 
    # Creates a link between instance and a link with primary fk.
    # The relationship between the two is defined by type. one_one
    # relationships are placing an additional call to delete_all_links
    # that will remove conflicts.
    # [param instance:] Instance of a class that refers to an existing database entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    # [param value:] primary key of the relationship, that is to be created
    def create_link(instance, link, type, fk)
      if type == "one_one"
        if (instance.class.name.downcase <=> link.name.downcase) < 0
          re = self.find(link.name, "WHERE #{link.primary_key[0]}=#{fk};")[0]
          self.delete_all_links re, instance.class, type
        end
        firstclass = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? instance.class : link
        secondclass = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? link : instance.class
        key = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? instance.class.primary_key[0] : link.primary_key[0]
        value = instance.method(instance.class.primary_key[0]).call
        fk_set = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? fk : value
        value_set = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? value : fk
        @db.query "UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key[0]}=#{fk} WHERE #{key}=#{value};"
      elsif type == "one_many" or type == "many_one"
        firstclass = (type == "one_many") ? instance.class : link
        secondclass = (type == "one_many") ? link : instance.class
        key = (type == "one_many") ? instance.class.primary_key[0] : link.primary_key[0]
        value = instance.method(instance.class.primary_key[0]).call
        fk_set = (type == "one_many") ? fk : value
        value_set = (type == "one_many") ? value : fk
        @db.query "UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key[0]}=#{fk_set} WHERE #{key}=#{value_set};"
      elsif type == "many_many"
        tablename1 = instance.class.table_name
        tablename2 = link.table_name
        union_class = ((instance.class.name.downcase <=> link.name.downcase) < 0) ? "#{tablename1}_#{tablename2}" : "#{tablename2}_#{tablename1}"
        value = instance.method(instance.class.primary_key[0]).call
        @db.query "INSERT INTO #{union_class} (#{instance.class.foreign_key[0]}, #{link.foreign_key[0]}) VALUES (#{value}, #{fk});"
      end
    end
    
    # Class method
    #
    # Formats a Time object according to the SQL TimeDate standard
    # [param date:] Time object
    # [returns:] Formatted string
    def self.format_date(date)
      (date.instance_of? Time) ? date.strftime("%Y-%m-%d %H:%M:%S") : ""
    end
    
  end
  
end

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
    # [param value:] String
    # [returns:] Object
    def self.transform_from_sql(value)
      if value =~ /^NULL$/
        nil
      elsif value =~ /^\d+$/
        value.to_i
      elsif value =~ /^\d+\.\d+$/
        value.to_f
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
      table_name = class_name.table_name
      pk_name = class_name.primary_key
      return if table_name.nil? or pk_name.nil?
      response = self.query("SELECT MAX(#{pk_name}) as id FROM #{table_name};")
      return (response.empty?) ? nil : response.first["id"]
    end

    # Instance method
    #
    # Delete something from the database.
    # [param class_name:] Defines the class name or class
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    def remove(class_name, params="")
      table_name = (class_name.is_a? Class) ? class_name.table_name :
        Ink::Model.str_to_tablename(class_name)
      return if table_name.nil?
      self.query("DELETE FROM #{table_name} #{params};")
    end

    # Instance method
    #
    # Retrieve class instances, that are loaded with the database result set.
    # [param class_name:] Defines the class name or class which should be
    #                     queried
    # [param params:] Additional SQL syntax like WHERE conditions (optional)
    # [returns:] Array of class_name instances from the SQL result set
    def find(class_name, params="")
      unless class_name.is_a?(Class)
        class_name = Ink::Model.classname(class_name)
      end
      result = Array.new
      table_name = class_name.table_name
      return result if table_name.nil?

      re = self.query("SELECT * FROM #{table_name} #{params};")
      re.each do |entry|
        instance = class_name.new entry
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
      class1 = Ink::Model.classname(class1) unless class1.is_a? Class
      class2 = Ink::Model.classname(class2) unless class2.is_a? Class
      result = Array.new
      relationship = nil
      class1.foreign.each do |k,v|
        relationship = v if k == class2.class_name
      end
      return result if relationship != "many_many"
      fk1 = class1.foreign_key
      pk2 = class2.primary_key
      fk2 = class2.foreign_key
      tablename1 = class1.table_name
      tablename2 = class2.table_name
      union_class = ((class1.class_name <=> class2.class_name) < 0) ?
        "#{tablename1}_#{tablename2}" :
        "#{tablename2}_#{tablename1}"
      re = self.query <<QUERY
SELECT #{tablename2}.* FROM #{union_class}, #{tablename2}
WHERE #{union_class}.#{fk1} = #{class1_id}
AND #{union_class}.#{fk2} = #{tablename2}.#{pk2} #{params};
QUERY
      re.each do |entry|
        instance = class2.new entry
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
      class1 = Ink::Model.classname(class1) unless class1.is_a? Class
      class2 = Ink::Model.classname(class2) unless class2.is_a? Class
      result = Array.new
      relationship = nil
      class1.foreign.each do |k,v|
        relationship = v if k == class2.class_name
      end
      return result if relationship == "many_many"
      re = Array.new
      fk1 = class1.foreign_key
      tablename1 = class1.table_name
      tablename2 = class2.table_name
      if ((class1.class_name <=> class2.class_name) < 0 and
          relationship == "one_one") or relationship == "one_many"
        re = self.query <<QUERY
SELECT * FROM #{tablename2}
WHERE #{class2.primary_key}=(
  SELECT #{class2.foreign_key} FROM #{tablename1}
  WHERE #{class1.primary_key}=#{class1_id}
);
QUERY
      else
        re = self.query <<QUERY
SELECT * FROM #{tablename2} WHERE #{fk1} = #{class1_id} #{params};
QUERY
      end

      re.each do |entry|
        instance = class2.new entry
        result.push instance
      end
      result
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
      result_array = self.find_references class1, class1_id, class2, params
      if result_array.length == 1
        result_array.first
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
    # [param instance:] Instance of a class that refers to an existing database
    #                   entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    def delete_all_links(instance, link, type)
      if type == "one_one"
        firstclass =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          instance.class : link
        secondclass =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          link : instance.class
        key =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          instance.class.primary_key : instance.class.foreign_key
        value = instance.method(instance.class.primary_key).call
        @db.query <<QUERY
UPDATE #{firstclass.table_name}
SET #{secondclass.foreign_key}=NULL
WHERE #{key}=#{value};
QUERY
      elsif type == "one_many" or type == "many_one"
        firstclass = (type == "one_many") ? instance.class : link
        secondclass = (type == "one_many") ? link : instance.class
        key = (type == "one_many") ? instance.class.primary_key :
          instance.class.foreign_key
        value = instance.method(instance.class.primary_key).call
        @db.query <<QUERY
UPDATE #{firstclass.table_name}
SET #{secondclass.foreign_key}=NULL
WHERE #{key}=#{value};
QUERY
      elsif type == "many_many"
        tablename1 = instance.class.table_name
        tablename2 = link.table_name
        union_class =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          "#{tablename1}_#{tablename2}" : "#{tablename2}_#{tablename1}"
        value = instance.method(instance.class.primary_key).call
        @db.query <<QUERY
DELETE FROM #{union_class} WHERE #{instance.class.foreign_key}=#{value};
QUERY
      end
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
      to_add = Array.new
      if value.is_a? Array
        value.each do |v|
          if v.instance_of? link
            to_add.push(v.method(link.primary_key).call)
          else
            to_add.push v
          end
        end
      elsif value.instance_of? link
        to_add.push(value.method(link.primary_key).call)
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
    # [param instance:] Instance of a class that refers to an existing database
    #                   entry
    # [param link:] the related class (not a String, but class reference)
    # [param type:] relationship type
    # [param value:] primary key of the relationship, that is to be created
    def create_link(instance, link, type, fk)
      if type == "one_one"
        if (instance.class.name.downcase <=> link.name.downcase) < 0
          re = self.find(link.name, "WHERE #{link.primary_key}=#{fk};").first
          self.delete_all_links re, instance.class, type
        end
        firstclass =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          instance.class : link
        secondclass =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          link : instance.class
        key =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          instance.class.primary_key : link.primary_key
        value = instance.method(instance.class.primary_key).call
        fk_set =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          fk : value
        value_set =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          value : fk
        @db.query <<QUERY
UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key}=#{fk}
WHERE #{key}=#{value};
QUERY
      elsif type == "one_many" or type == "many_one"
        firstclass = (type == "one_many") ? instance.class : link
        secondclass = (type == "one_many") ? link : instance.class
        key = (type == "one_many") ? instance.class.primary_key :
          link.primary_key
        value = instance.method(instance.class.primary_key).call
        fk_set = (type == "one_many") ? fk : value
        value_set = (type == "one_many") ? value : fk
        @db.query <<QUERY
UPDATE #{firstclass.table_name} SET #{secondclass.foreign_key}=#{fk_set}
WHERE #{key}=#{value_set};
QUERY
      elsif type == "many_many"
        tablename1 = instance.class.table_name
        tablename2 = link.table_name
        union_class =
          ((instance.class.name.downcase <=> link.name.downcase) < 0) ?
          "#{tablename1}_#{tablename2}" : "#{tablename2}_#{tablename1}"
        value = instance.method(instance.class.primary_key).call
        @db.query <<QUERY
INSERT INTO #{union_class}
(#{instance.class.foreign_key}, #{link.foreign_key}) VALUES (#{value}, #{fk});
QUERY
      end
    end
  end

end

module Ink

  # = Model class
  #
  # == Usage
  #
  # Models are usually derived from. So let's assume there is a
  # class called Apple < Ink::Model
  #
  #   apple = Apple.new {:color => "red", :diameter => 4}
  #   apple = Apple.new [ "red", 4 ]
  #
  # The constructor checks, if there are class methods 'fields'
  # and 'foreign' defined. If that check is positive, it will
  # match the parameter Hash to the fields, that are set for
  # the database, and throw an exception if fields is lacking
  # an entry (excluded the primary key). The other case just
  # creates an Apple with the Hash as instance variables.
  # An alternate method of creating a new apple is by providing
  # an Array of values in the same order as in the fields
  # definition.
  #
  #   puts apple.color
  #
  # This prints "red" to the stdout, since getter and setter
  # methods are automatically added for either the Hash, or
  # the fields and foreign keys.
  #
  #   apple.save
  #
  # You can save your apple by using the save method. New instances
  # will create a new row in the database, and update its primary
  # key. Old instances just update the fields. Relationships are set
  # to nil by default and will not be touched while nil.
  #
  #   treeinstance.apple = [1,2,myapple]
  #   treeinstance.save
  #
  # To insert relationship data, you can provide them by array, value
  # or reference, so setting treeinstance.apple to 1 is allowed, also
  # to myapple, or an array or a combination. An empty array [] will
  # remove all references. This works both ways, just consider the
  # relationship type, as an apple cannot have more than one tree.
  #
  #   treeinstance.delete
  #
  # The model provides a convenience method for deletion. It removes all
  # references from relationships, but does not remove the relationships
  # themselves, so you must fetch all related data, and delete them by
  # 'hand' if you will.
  #
  #   treeinstance.find_references Apple
  #
  # This convenience method finds all apples for this tree and makes
  # them available in the accessor. If the Tree-Apple relationship is
  # a *_one, then there is only one object in the accessor, otherwise
  # an Array of objects.
  #
  #
  # == Fields and foreign sample config
  #
  #   class Apple < Ink::Model
  #     def self.fields
  #       fields = {
  #         :id => "PRIMARY KEY"
  #         :color => [ "VARCHAR", "NOT NULL" ],
  #         :diameter => [ "NUMERIC", "NOT NULL" ]
  #       }
  #       fields
  #     end
  #     def self.foreign
  #       foreign = {
  #         "Tree" => "one_many"
  #       }
  #       foreign
  #     end
  #   end
  #
  # Let's look at this construct.
  # The constructor is inherited from Ink::Model, so are its
  # methods. 'fields' defines a Hash of Arrays, that will
  # create the Database table for us.
  # 'foreign' handles the contraints to other classes, here
  # it reads: one "Tree" has many Apples, other constructs
  # could be: [one "Tree" has one Apple, many "Tree"s have
  # many Apples, many "Tree"s have one Apple] => [one_one,
  # many_many, many_one]
  # Obviously the Tree class requires a foreign with "Apple"
  # mapped to "many_one" to match this schema.
  #
  # You can override the automatically generated getters and
  # setters in any Model class you create by just redefining
  # the methods.
  #
  # == Convenience methods
  #
  #   self.primary_key
  #   self.primary_key_type
  #   self.foreign_key
  #   self.foreign_key_type
  #
  # primary_key is the name of the primary key (default "id").
  # The foreign_key has a combination of "classname"_"primary_key"
  # (i.e. "apple_id")
  #
  #   self.class_name
  #
  # Equivalent to class.name
  #
  #   self.table_name
  #
  # Generates a table representation of the class. (Apple as
  # "apple" and MyApple as "my_apple")
  #
  #   self.str_to_classname(str)
  #
  # Converts a table name to class name. This method takes a string.
  #
  #   self.str_to_tablename(str)
  #
  # Converts a class name to table name. This method takes a string.
  #
  #
  #
  class Model

    # Constructor
    #
    # Model without fields will take only a Hash and set accessors
    # for all hash-keys given.
    # Model with fields will initialize accessors according to
    # fields and foreign definitions and, if applicable, call
    # #update_fields on the arguments.
    # Primary keys receive an addition getter and setter called 'pk'.
    # Foreign keys receive two getters and setters each, one is the
    # snakecase representation of the associated model and the other
    # is the foreign key respectively.
    # [param data:] (Hash of String => Objects) or (Array of Objects)
    def initialize(*data)
      if self.class.respond_to?(:fields)
        self.class.fields.keys.each{ |k| init_field(k) }
      elsif data.length == 1 && data.first.is_a?(Hash)
        data.first.each do |k, v|
          init_field(k)
        end
      end

      if self.class.respond_to?(:foreign)
        self.class.foreign.keys.each{ |k| init_foreign(k) }
      end

      update_fields(*data)
    end

    # Public instance method
    #
    # Will attempt to assign hash-values to the keys used as methods.
    # When setting an array, it will be matched against the fields
    # in the order the fields are defined. The array can contain the
    # primary key or not.
    # [param data:] (Hash of String => Objects) or (Array of Objects)
    def update_fields(*data)
      if data.length == 1 && data.first.is_a?(Hash)
        data = data.first
      end

      validate_update_fields(data)

      if self.class.respond_to?(:fields)
        if data.is_a?(Array)
          data = update_fields_data_to_hash(data)
        end
      end

      data.each{ |k, v| self.send("#{k}=", v) }
    end

    # Private instance method
    #
    # Validates the given data if fields are defined on the model.
    # If data is an array and not empty, it has to match the length
    # of the fields or the length without the primary key.
    # [param data:] (Hash of String => Objects) or (Array of Objects)
    def validate_update_fields(data)
      return unless self.class.respond_to?(:fields)

      if data.is_a?(Array) && !data.empty?
        if data.length < self.class.fields.length - 1 or
            data.length > self.class.fields.length
          raise LoadError.new(<<-ERR)
            Model cannot be loaded, wrong number or arguments for Array:
            #{data.length} expected #{self.class.fields.length}
            or #{self.class.fields.length - 1}
          ERR
        end
      end
    end
    private :validate_update_fields

    # Private instance method
    #
    # Assigns the array values to the respective fields keys.
    # [param data:] Array of Objects
    # [returns:] Hash of field-key => array-values
    def update_fields_data_to_hash(data)
      field_keys = self.class.fields.keys

      if data.length < field_keys.length
        field_keys.reject!{ |k| k == self.class.primary_key }
      end

      data_hash = field_keys.zip(data)

      return data_hash.reduce({}){ |acc, (k, v)| acc.merge({ k => v }) }
    end
    private :update_fields_data_to_hash

    # Class method
    #
    # Similar to making an Object sql safe.
    # Escapes quotes.
    # [param value:] Object
    # [returns:] safe Object
    def self.make_safe(value)
      if value.nil?
        nil
      elsif value.is_a?(String)
        value.gsub(/'/, '&#39;')
      elsif value.is_a?(Numeric)
        value
      else
        "\'#{value}\'"
      end
    end

    # Private instance method
    #
    # Provides an instance getter and setter for the key.
    # Primary keys receive an extra 'pk' getter and setter.
    # [key:] String
    def init_field(key)
      if key.to_s.downcase == "pk"
        raise NameError.new(<<-ERR)
          Model cannot use #{key} as field, it is blocked by primary key
        ERR
      end

      unless self.respond_to?(key)
        self.class.send(:define_method, key) do
          instance_variable_get("@#{key}")
        end
      end
      unless self.respond_to?("#{key}=")
        self.class.send(:define_method, "#{key}=") do |val|
          val = self.class.make_safe(val)
          instance_variable_set("@#{key}", val)
        end
      end
      if self.class.primary_key == key
        self.class.send(:define_method, "pk") do
          instance_variable_get("@#{key}")
        end
        self.class.send(:define_method, "pk=") do |val|
          val = self.class.make_safe(val)
          instance_variable_set("@#{key}", val)
        end
      end
    end
    private :init_field

    # Private instance method
    #
    # Transforms the key to snakecase and foreign_key of the associated
    # model. It then provides an instance getter and setter for both
    # accessing the same underlying instance variable.
    # [key:] String
    def init_foreign(key)
      k = key.underscore
      klass = key.constantize
      self.class.send(:define_method, k) do
        instance_variable_get("@#{k}")
      end
      self.class.send(:define_method, "#{k}=") do |val|
        instance_variable_set("@#{k}", val)
      end
      self.class.send(:define_method, klass.foreign_key) do
        instance_variable_get("@#{k}")
      end
      self.class.send(:define_method, "#{klass.foreign_key}=") do |val|
        instance_variable_set("@#{k}", val)
      end
    end
    private :init_foreign

    # Instance method
    #
    # Save the instance to the database. Set all foreign sets to
    # nil if you do not want to change them. Old references are
    # automatically removed.
    def save
      unless self.class.respond_to?(:fields)
        raise NotImplementedError.
          new("Cannot save to Database without field definitions")
      end

      column_value_map = self.class.fields.keys.reduce({}) do |acc, k|
        v = Ink::SqlAdapter.transform_to_sql(self.send(k))
        acc["`#{k}`"] = v unless k == self.class.primary_key
        acc
      end

      query = Ink::R::RelationString.new
      if self.pk.nil? || self.class.find.where("`#{self.class.primary_key}`=" +
        "#{Ink::SqlAdapter.transform_to_sql(self.pk)}").to_a.empty?

        query.insert.into(self.class.table_name).
          send(' _!', column_value_map.keys.join(',')).
          values.send(' _!', column_value_map.values.join(',')).execute

        self.pk = Ink::Database.database.last_inserted_pk(self.class)
      else
        query.update(self.class.table_name).
          set(column_value_map.map{ |k, v| "#{k}=#{v}" }.join(',')).
          where("`#{self.class.primary_key}`=" +
          "#{Ink::SqlAdapter.transform_to_sql(self.pk)}").execute
      end

      if self.class.respond_to?(:foreign)
        self.class.foreign.each do |k,v|
          value = self.send(k.underscore)
          if value
            Ink::Database.database.delete_all_links(self,
              Ink::Model.classname(k), v)
            Ink::Database.database.create_all_links(self,
              Ink::Model.classname(k), v, value)
          end
        end
      end
    end

    # Instance method
    #
    # Deletes the data from the database, essentially making the instance
    # obsolete. Disregard from using the instance anymore.
    # All links between models will be removed also.
    def delete
      if not self.class.respond_to? :fields
      raise NotImplementedError.new(<<ERR)
Cannot delete from Database without field definitions
ERR
      end
      if self.class.respond_to? :foreign
        self.class.foreign.each do |k,v|
          Ink::Database.database.delete_all_links(self,
            Ink::Model.classname(k), v)
        end
      end

      pkvalue = instance_variable_get "@#{self.class.primary_key}"
      Ink::Database.database.remove self.class.name, <<QUERY
WHERE `#{self.class.primary_key}`=#{
(pkvalue.is_a?(Numeric)) ? pkvalue : "\'#{pkvalue}\'"
}
QUERY
    end

    def self.find
      return Ink::R.select('*').from(self.table_name)
    end

    # Instance method
    #
    # Queries the database for foreign keys and attaches them to the
    # matching foreign accessor
    # [param foreign_class:] Defines the foreign class name or class
    def find_references(foreign_class)
      c = (foreign_class.is_a? Class) ? foreign_class :
        Ink::Model.classname(foreign_class)
      relationship = self.class.foreign[c.class_name]
      if relationship
        result_array = (relationship == "many_many") ?
          Ink::Database.database.find_union(self.class, self.pk, c) :
          Ink::Database.database.find_references(self.class, self.pk, c)
        instance_variable_set("@#{c.table_name}",
          (relationship =~ /^one_/) ? result_array.first : result_array)
        true
      else
        false
      end
    end

    # Class method
    #
    # This will create SQL statements for creating the
    # database tables. 'fields' method is mandatory for
    # this, and 'foreign' is optional.
    # [returns:] Array of SQL statements
    def self.create
      result = Array.new
      if not self.respond_to?(:fields)
        puts "Skipping #{self.name}...."
        return []
      end

      string = "CREATE TABLE #{self.table_name} ("
      mfk = self.foreign_key
      string += self.fields.map do |k,v|
        if k != self.primary_key
          "`#{k}` #{v*" "}"
        else
          "#{Ink::Database.database.primary_key_autoincrement(k)*" "}"
        end
      end.join(",")

      if self.respond_to? :foreign
         tmp = self.foreign.map do |k,v|
           f_class = Ink::Model::classname(k)
           if v == "many_many" and (self.name <=> k) < 0
             result.push <<QUERY
CREATE TABLE #{self.table_name}_#{Ink::Model::str_to_tablename(k)}
(#{Ink::Database.database.primary_key_autoincrement*" "},
`#{self.foreign_key}` #{self.foreign_key_type},
`#{f_class.foreign_key}` #{f_class.foreign_key_type});
QUERY
             nil
           end
           if v == "one_many" or (v == "one_one" and (self.name <=> k) < 0)
             "`#{f_class.foreign_key}` #{f_class.foreign_key_type}"
           else
             nil
           end
         end.compact.join(",")
         string += ",#{tmp}" if not tmp.empty?
      end
      string += ");"
      result.push string
      result
    end

    # Class method
    #
    # This will retrieve a string-representation of the model name
    # [returns:] valid classname
    def self.class_name
      self.name
    end

    # Class method
    #
    # This will retrieve a tablename-representation of the model name
    # [returns:] valid tablename
    def self.table_name
      self.name.underscore
    end

    # Class method
    #
    # This will check the parent module for existing classnames
    # that match the input of the str parameter.
    # [param str:] some string
    # [returns:] valid classname or nil
    def self.str_to_classname(str)
      res = []
      str.scan(/((^|_)([a-z0-9]+))/) { |s|
        if s.length > 0
          res.push(s[2][0].upcase +
            ((s[2].length > 1) ? s[2][1,s[2].length] : ""))
        end
      }
      Module.const_get(res.join).is_a?(Class) ? res.join : nil
    end

    # Class method
    #
    # This will check the parent module for existing classnames
    # that match the input of the str parameter. Once found, it
    # converts the string into the matching tablename.
    # [param str:] some string
    # [returns:] valid tablename or nil
    def self.str_to_tablename(str)
      res = []
      str.scan(/([A-Z][a-z0-9]*)/) { |s|
        res.push (res.length>0) ? "_" + s.join.downcase : s.join.downcase
      }
      Module.const_get(str).is_a?(Class) ? res.join : nil
    end

    # Class method
    #
    # This will check the parent module for existing classnames
    # that match the input of the str parameter. Once found, it
    # returns the class, not the string of the class.
    # [param str:] some string
    # [returns:] valid class or nil
    def self.classname(str)
      res = []
      if str[0] =~ /^[a-z]/
        str.scan(/((^|_)([a-z0-9]+))/) { |s|
          if s.length > 0
            res.push(s[2][0].upcase +
              ((s[2].length > 1) ? s[2][1,s[2].length] : ""))
          end
        }
      else
        res.push str
      end
      Module.const_get(res.join).is_a?(Class) ? Module.const_get(res.join) : nil
    end

    # Class method
    #
    # This will find the primary key, as defined in the fields class
    # method.
    # [returns:] key name or nil
    def self.primary_key
      if self.respond_to? :fields
        field = self.fields.select{|k,v| v.is_a?(String) and v == "PRIMARY KEY"}
        return field.keys.first
      end
      nil
    end

    # Class method
    #
    # This will find the primary key type, as defined in the fields
    # class method.
    # [returns:] key type or nil
    def self.primary_key_type
      if self.respond_to? :fields
        field = self.fields.select{|k,v| v.is_a?(String) and v == "PRIMARY KEY"}
        return Ink::Database.database.
          primary_key_autoincrement(field.keys.first)[1]
      end
      nil
    end

    # Class method
    #
    # This will create the foreign key from the defined primary key
    # [returns:] key name or nil
    def self.foreign_key
      pk = self.primary_key
      return (pk) ? "#{self.table_name}_#{pk}" : nil
    end

    # Class method
    #
    # This will find the foreign key type, taken from the primary key
    # in fields.
    # [returns:] key type or nil
    def self.foreign_key_type
      self.primary_key_type
    end

  end

end

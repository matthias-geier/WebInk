module Ink

  # = Model class
  #
  # == Usage
  #
  # Models are usually derived from. So let's assume there is a
  # class called Apple < Ink::Model
  #
  #   apple = Apple.new(:color => "red", :diameter => 4, :tree_id => Tree.new)
  #   # equals to
  #   apple = Apple.new("red", 4)
  #   apple.tree_id = Tree.new
  #
  # The constructor initializes an object will accessors to all
  # 'fields', to the primary key additionally with #pk and #pk=
  # and finally to 'foreigns' with both the underscore representation
  # of the associated class name and respectively with the added
  # primary key.
  #
  #   apple.color
  #   => "red"
  #
  # The constructor utilizes the update_fields method which provide
  # a generic update interface for arrays and hashes.
  # Hashes are set by assuming the 'key' is the method name and the
  # assigned value is the future assigned value.
  # Arrays are more complicated. It is assumed the array values are
  # the same order as the 'fields', with or without the primary key,
  # that is choosable. The array values are then matched against the
  # 'fields' and treated as hash onwards.
  #
  #   apple.save
  #
  # You can save your apple by using the save method. New instances
  # will create a new row in the database, and update the object's
  # primary key. Old instances just update the fields. Relationships
  # are set to nil by default and will not be touched while nil.
  #
  #   tree = Tree.new
  #   tree.apple = [1,2,apple]
  #   tree.save
  #
  # To insert relationship data, you can provide them by array, value
  # or reference, so setting tree.apple to 1 is allowed, also
  # to apple, or an array or a combination. An empty array [] will
  # remove all references. This works both ways, just consider the
  # relationship type, as an apple cannot have more than one tree.
  # Should you add more trees on the apple, the last one counts.
  #
  #   tree.delete
  #
  # The model provides a convenience method for deletion. It removes all
  # references from relationships.
  #
  #   tree.find_references(Apple)
  #   => [apple]
  #   tree.apple
  #   => [apple]
  #   tree.apple_id
  #   => [25]
  #
  #   apple.find_references(Tree)
  #   => tree
  #   apple.tree
  #   => tree
  #   apple.tree_ref
  #   => 3
  #
  # This convenience method finds all apples for this tree and makes
  # them available in the accessors. If the Tree-Apple relationship is
  # a *_one, then there is only one object in the accessor, otherwise
  # an Array of objects.
  #
  # When calling the accessor with the primary key as suffix, it will
  # attempt to map the objects to their primary keys.
  #
  #   Apple.find{ |s| s.where(Tree.foreign_key + ">=3") }
  #   => [apple]
  #   Apple.find
  #   => [apple, ....]
  #
  # Model finders allow a quick way of fetching an array of objects
  # which is filtered by the block given. The block takes an sql builder
  # instance. The method itself generates an sql similar to:
  #
  #   SELECT * FROM apple
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
  #   self.table_name
  #
  # Generates a table representation of the class. (Apple as
  # "apple" and MyApple as "my_apple"). Essentially equivalent to
  # snakecase.
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
        self.class.init_associations
      end

      self.update_fields(*data)
    end

    def self.associations
      unless @associations
        self.init_associations
      end
      return @associations
    end

    def self.init_associations
      @associations = {}
      return if !self.respond_to?(:foreign)

      self.foreign.each do |k, v|
        assoc = "Ink::Association::#{v.camelize}".constantize
        klass = k.constantize
        @associations[klass] = assoc.new(self, klass)
      end
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

      data.each do |k, v|
        next unless self.respond_to?("#{k}=")
        self.send("#{k}=", v)
      end
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
            with content #{data.inspect} for #{self.class.fields.keys.inspect}
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

    # Private instance method
    #
    # Provides an instance getter and setter for the key.
    # Primary keys receive an extra 'pk' getter and setter.
    # [param key:] String
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
          instance_variable_set("@#{key}", val)
        end
      end
      if self.class.primary_key == key
        self.class.send(:define_method, "pk") do
          instance_variable_get("@#{key}")
        end
        self.class.send(:define_method, "pk=") do |val|
          instance_variable_set("@#{key}", val)
        end
      end
    end
    private :init_field

    # Private instance method
    #
    # Map association contents to primary keys only
    # [param values:] Association data
    # [returns:] A mapped version of the association data
    def map_association_values_to_primary_keys(values)
      transform = lambda{ |v| v.is_a?(Ink::Model) ? v.pk : v }
      if values.is_a?(Array)
        values.map{ |v| transform.call(v) }
      else
        transform.call(values)
      end
    end

    # Private instance method
    #
    # Transforms the key to snakecase and foreign_key of the associated
    # model. It then provides an instance getter and setter for both
    # accessing the same underlying instance variable.
    # [param key:] String
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
        values = instance_variable_get("@#{k}")
        self.map_association_values_to_primary_keys(values)
      end
      self.class.send(:define_method, "#{klass.foreign_key}=") do |val|
        instance_variable_set("@#{k}", val)
      end
    end
    private :init_foreign

    # Public instance method
    #
    # Save the instance to the database. Set all foreign sets to
    # nil if you do not want to change them. Old references are
    # automatically removed if the set value is not nil. To clean up
    # associations, set the value to empty array.
    # Values are automatically escaped.
    def save
      unless self.class.respond_to?(:fields)
        raise NotImplementedError.
          new("Cannot save to Database without field definitions")
      end

      column_value_map = self.class.fields.keys.reduce({}) do |acc, k|
        v = Ink::SqlAdapter.transform_to_sql(self.send(k))
        acc[k] = v unless k == self.class.primary_key
        acc
      end

      query = Ink::R::RelationString.new
      if self.pk.nil? || self.class.find{ |s|
        s.where("#{self.class.primary_key}=" +
        "#{Ink::SqlAdapter.transform_to_sql(self.pk)}") }.empty?

        query.insert.into(self.class.table_name).
          send(' _!', column_value_map.keys.join(',')).
          values.send(' _!', column_value_map.values.join(',')).execute

        self.pk = Ink::Database.database.last_inserted_pk(self.class)
      else
        query.update(self.class.table_name).
          set(column_value_map.map{ |k, v| "#{k}=#{v}" }.join(',')).
          where("#{self.class.primary_key}=" +
          "#{Ink::SqlAdapter.transform_to_sql(self.pk)}").execute
      end

      self.clear_associations
      self.assign_associations
    end

    # Protected instance method
    #
    # Clean up all associations that are not nil (empty array works
    # as a cleanup indicator)
    def clear_associations
      return unless self.class.respond_to?(:foreign)

      self.class.associations.each do |k, v|
        value = self.send(k.name.underscore)
        next if self.pk.nil? || value.nil?

        v.delete_all_associations(self.pk)
      end
    end
    protected :clear_associations

    # Protected instance method
    #
    # Assign all not-nil association values which can be objects or
    # primary key values.
    def assign_associations
      return unless self.class.respond_to?(:foreign)

      self.class.associations.each do |k, v|
        value = self.send(k.name.underscore)
        next if self.pk.nil?

        v.assign_all_associations(self.pk, value)
      end
    end
    protected :assign_associations

    # Instance method
    #
    # Deletes the data from the database, essentially making the instance
    # obsolete. Disregard from using the instance anymore.
    # All links between models will be removed also.
    # Saving the model again will recreate it with a new primary key.
    def delete
      unless self.class.respond_to?(:fields)
        raise NotImplementedError.
          new("Cannot delete from Database without field definitions")
      end
      self.clear_associations

      pk_value = Ink::SqlAdapter.transform_to_sql(self.pk)
      Ink::R.delete.from(self.class.table_name).
        where("#{self.class.primary_key}=#{pk_value}").execute
    end

    def self.find
      query = Ink::R.select('*').from(self.table_name)
      if block_given?
        query = yield(query)
      end
      return query.to_h.map do |row|
        self.new(row)
      end
    end

    # Public instance method
    #
    # Queries the database for foreign keys and attaches them to the
    # matching foreign accessor
    # [param foreign_class:] Defines the foreign class name or class
    # [yield(Ink::R::RelationString instance):] yield a block with one argument
    #   that is attached by AND to the query
    # [returns:] Array of found objects or one object for /^one_/ associations
    def find_references(klass, &blk)
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)
      if !self.class.respond_to?(:foreign) || !self.class.associations[klass]
        return nil
      end

      result = self.class.associations[klass].find_references(self.pk, &blk)

      self.send("#{klass.name.underscore}=", result)
      return result
    end

    # Class method
    #
    # This will create SQL statements for creating the
    # database tables. 'fields' method is mandatory for
    # this, and 'foreign' is optional.
    # [returns:] Array of SQL statements
    def self.create
      unless self.respond_to?(:fields)
        puts "Skipping #{self.name}...."
        return []
      end

      tables, foreign_fields = self.associations.
        reduce([[], []]) do |acc, (_, v)|

        acc[0] += v.tables_for_create
        acc[1] += v.foreign_fields_for_create
        acc
      end

      sql = Ink::R.create.table(self.table_name)._! do |_|
        cols = self.fields.map do |k, v|
          if k == self.primary_key
            Ink::Database.database.primary_key_autoincrement(k).join(' ')
          else
            "#{k} #{v.join(' ')}"
          end
        end
        cols += foreign_fields
        cols.join(',')
      end

      tables << sql.to_sql
      return tables
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

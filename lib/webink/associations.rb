
module Ink
  module Associations
    module ClassMethods
      def join_table_for(klass)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        return [self.table_name, klass.table_name].sort.join('_')
      end

      def foreign_key_table_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return [self.table_name, klass.table_name].sort.first
        elsif assoc_type == 'one_many'
          return self.table_name
        elsif assoc_type == 'many_one'
          return klass.table_name
        else
          self.join_table_for(klass)
        end
      end

      def update_key_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return [self.foreign_key, klass.foreign_key].sort.last
        elsif ['many_one', 'many_many'].include?(assoc_type)
          return self.foreign_key
        elsif assoc_type == 'one_many'
          return klass.foreign_key
        end
      end

      def delete_where_key_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return self.send((self.foreign_key <=> klass.foreign_key) < 0 ?
            :primary_key : :foreign_key)
        elsif ['many_one', 'many_many'].include?(assoc_type)
          return self.foreign_key
        elsif assoc_type == 'one_many'
          return self.primary_key
        end
      end

      def assign_where_key_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return [self, klass].sort{ |a, b| a.foreign_key <=> b.foreign_key }.
            first.primary_key
        elsif ['many_one', 'many_many'].include?(assoc_type)
          return klass.primary_key
        elsif assoc_type == 'one_many'
          return self.primary_key
        end
      end
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

    def delete_all_associations(klass, assoc_type)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

      if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
        Ink::R.update(self.class.foreign_key_table_for(klass, assoc_type)).
          set("`#{self.class.update_key_for(klass, assoc_type)}`=NULL").
          where("`#{self.class.delete_where_key_for(klass,
          assoc_type)}`=#{self.pk}").execute
      else
        Ink::R.delete.from(self.class.foreign_key_table_for(klass, assoc_type)).
          where("`#{self.class.delete_where_key_for(klass,
          assoc_type)}`=#{self.pk}").execute
      end
    end

    def assign_all_associations(klass, assoc_type, value)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

      values = [value].flatten.map{ |v| v.is_a?(klass) ? v.pk : v }
      values.each do |v|
        next if v.nil?

        if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
          set_key = self.class.update_key_for(klass, assoc_type)
          search_key = self.class.assign_where_key_for(klass, assoc_type)
          vals = [v, self.pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }
          if assoc_type == 'many_one'
            vals.reverse!
          end
          set_value, search_value = vals

          p Ink::R.update(self.class.foreign_key_table_for(klass, assoc_type)).
            set("`#{set_key}`=#{set_value}").
            where("`#{search_key}`=#{search_value}").to_sql
        else
          foreign_keys = [self.class.foreign_key, klass.foreign_key].map do |f|
            "`#{f}`"
          end
          vals = [self.pk, v].map do |val|
            Ink::SqlAdapter.transform_to_sql(val)
          end

          Ink::R.insert.
            into(self.class.foreign_key_table_for(klass, assoc_type)).
            send(' _!', foreign_keys.join(',')).
            values.send(' _!', vals.join(',')).execute
        end
      end
    end
  end
end

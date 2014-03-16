
module Ink
  module Associations
    module ClassMethods
      def order_table_names_for(klass)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        return [self, klass].sort{ |a, b| a.table_name <=> b.table_name }
      end

      def join_table_for(klass)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        return [self.table_name, klass.table_name].sort.join('_')
      end

      def foreign_key_table_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return self.order_table_names_for(klass).table_name.first
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

      def create_foreign_column_definitions
        return [[], []] unless self.respond_to?(:foreign)

        tables = []
        foreign_fields = self.foreign.reduce([]) do |acc, (k, v)|
          klass = k.constantize

          if v == 'many_many' && self.order_table_names_for(k).first == self
            tables << Ink::R.create.table(self.join_table_for(k))._! do |s|
              cols = []
              cols << Ink::Database.database.primary_key_autoincrement.join(' ')
              cols += [self, klass].map do |elem|
                "`#{elem.foreign_key}` #{elem.foreign_key_type}"
              end
              next cols.join(',')
            end.to_sql
          elsif v == 'one_many' ||
            (v == 'one_one' && self.order_table_names_for(k).first == self)

            acc << "`#{klass.foreign_key}` #{klass.foreign_key_type}"
          end
          next acc
        end

        return [tables, foreign_fields]
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
    def find_references(klass)
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)
      if !self.class.respond_to?(:foreign) || !self.class.foreign[klass.name]
        return nil
      end
      assoc_type = self.class.foreign[klass.name]

      result = klass.find do |s|
        s.where("`#{klass.primary_key}`").in! do |sub|
          select_key, where_key = case assoc_type
          when 'many_many'
            [klass.foreign_key, self.class.foreign_key]
          when 'one_many'
            [klass.foreign_key, self.class.primary_key]
          when 'many_one'
            [klass.primary_key, self.class.foreign_key]
          when 'one_one'
            if self.class.order_table_names_for(klass).first == self
              [klass.foreign_key, self.class.primary_key]
            else
              [klass.primary_key, self.class.foreign_key]
            end
          end
          sub.select("`#{select_key}`").
            from(self.class.foreign_key_table_for(klass, assoc_type)).
            where("`#{where_key}`=#{Ink::SqlAdapter.transform_to_sql(self.pk)}")
        end

        if block_given?
          s.and!{ |sub| yield(sub) }
        end

        next s
      end

      if assoc_type.match(/^one_/)
        result = result.first
      end

      self.send("#{klass.name.underscore}=", result)
      return result
    end

    def delete_all_associations(klass, assoc_type)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)
      return if self.send(klass.name.underscore).nil?

      if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
        where_key = case assoc_type
        when 'many_one'
          self.class.foreign_key
        when 'one_many'
          self.class.primary_key
        when 'one_one'
          self.class.order_table_names_for(klass).first == self ?
            self.class.primary_key : self.class.foreign_key
        end

        Ink::R.update(self.class.foreign_key_table_for(klass, assoc_type)).
          set("`#{self.class.update_key_for(klass, assoc_type)}`=NULL").
          where("`#{where_key}`=#{self.pk}").execute
      else
        Ink::R.delete.from(self.class.foreign_key_table_for(klass, assoc_type)).
          where("`#{self.class.foreign_key}`=#{self.pk}").execute
      end
    end
    protected :delete_all_associations

    def assign_all_associations(klass, assoc_type, value)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

      values = [value].flatten.map{ |v| v.is_a?(klass) ? v.pk : v }
      values.each do |v|
        next if v.nil?

        vals = [v, self.pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }
        if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
          set_key = self.class.update_key_for(klass, assoc_type)
          search_key = case assoc_type
          when 'one_one'
            self.class.order_table_names_for(klass).first.primary_key
          when 'many_one'
            klass.primary_key
          when 'one_many'
            self.class.primary_key
          end
          if assoc_type == 'many_one'
            vals.reverse!
          end
          set_value, search_value = vals

          Ink::R.update(self.class.foreign_key_table_for(klass, assoc_type)).
            set("`#{set_key}`=#{set_value}").
            where("`#{search_key}`=#{search_value}").execute
        else
          foreign_keys = [klass.foreign_key, self.class.foreign_key].map do |f|
            "`#{f}`"
          end

          Ink::R.insert.
            into(self.class.foreign_key_table_for(klass, assoc_type)).
            send(' _!', foreign_keys.join(',')).
            values.send(' _!', vals.join(',')).execute
        end
      end
    end
    protected :assign_all_associations
  end
end


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
          return klass.table_name
        elsif assoc_type == 'many_one'
          return self.table_name
        else
          self.join_table_for(klass)
        end
      end

      def update_key_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return [self.foreign_key, klass.foreign_key].sort.last
        elsif ['one_many', 'many_many'].include?(assoc_type)
          return self.foreign_key
        elsif assoc_type == 'many_one'
          return klass.foreign_key
        end
      end

      def where_key_for(klass, assoc_type)
        klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

        if assoc_type == 'one_one'
          return self.send((self.foreign_key <=> klass.foreign_key) < 0 ?
            :primary_key : :foreign_key)
        elsif ['one_many', 'many_many'].include?(assoc_type)
          return self.foreign_key
        elsif assoc_type == 'many_one'
          return self.primary_key
        end
      end
    end

    def delete_all_associations(klass, assoc_type)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

      if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
        Ink::R.update(self.class.foreign_key_table_for(klass, assoc_type)).
          set("`#{self.class.update_key_for(klass, assoc_type)}`=NULL").
          where("`#{self.class.where_key_for(klass, assoc_type)}`=#{self.pk}").
          execute
      else
        Ink::R.delete.from(self.class.foreign_key_table_for(klass, assoc_type)).
          where("`#{self.class.where_key_for(klass, assoc_type)}`=#{self.pk}").
          execute
      end
    end

    def assign_all_associations(klass, assoc_type, value)
      return if self.pk.nil?
      klass = klass.to_s.constantize unless klass.is_a?(Ink::Model)

      values = [value].flatten.map{ |v| v.is_a?(klass) ? v.pk : v }
      values.each do |v|
        next if v.nil?

        if ['one_one', 'one_many', 'many_one'].include?(assoc_type)
        else
          Ink::R.insert.
            into(self.class.foreign_key_table_for(klass, assoc_type)).
            send(' _!', [self.class.foreign_key, klass.foreign_key].join(',')).
            values.send(' _!', [self.pk, v].join(','))
        end
      end
    end
  end
end


module Ink
  module Association
    class OneOne < Associations
      def foreign_key_table
        return self.ordered_tables.first.table_name
      end

      def update_key
        return self.ordered_tables.last.foreign_key
      end

      def foreign_fields_for_create
        return [] unless self.ordered_tables.first == @klass

        return ["#{@related_klass.foreign_key} " +
          "#{@related_klass.foreign_key_type}"]
      end

      def find_references(pk, &blk)
        select_key, where_key = if self.ordered_tables.first == @klass
          [@related_klass.foreign_key, @klass.primary_key]
        else
          [@related_klass.primary_key, @klass.foreign_key]
        end
        super(pk, select_key, where_key, &blk).first
      end

      def delete_all_associations(pk)
        where_key = self.ordered_tables.first == @klass ? @klass.primary_key :
          @related_klass.primary_key
        Ink::R.update(self.foreign_key_table).
          set("#{self.update_key}=NULL").
          where("#{where_key}=#{pk}").execute
      end

      def assign_all_associations(pk, value)
        values = [value].flatten.map{ |v| v.is_a?(@related_klass) ? v.pk : v }
        values.each do |v|
          next if v.nil?

          v, pk = [v, pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }
          if self.ordered_tables.last == @klass
            v, pk = [v, pk].reverse
          end

          Ink::R.update(self.foreign_key_table).
            set("#{self.update_key}=#{v}").
            where("#{self.ordered_tables.first.primary_key}=#{pk}").execute
        end
      end
    end
  end
end

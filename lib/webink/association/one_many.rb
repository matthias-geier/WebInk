
module Ink
  module Association
    class OneMany < Associations
      def foreign_key_table
        return @klass.table_name
      end

      def update_key
        return @related_klass.foreign_key
      end

      def foreign_fields_for_create
        return ["`#{@related_klass.foreign_key}` " +
          "#{@related_klass.foreign_key_type}"]
      end

      def find_references(pk, &blk)
        super(pk, @related_klass.foreign_key, @klass.primary_key, &blk).first
      end

      def delete_all_associations(pk)
        Ink::R.update(self.foreign_key_table).
          set("`#{self.update_key}`=NULL").
          where("`#{@klass.primary_key}`=#{pk}").execute
      end

      def assign_all_associations(pk, value)
        values = [value].flatten.map{ |v| v.is_a?(@related_klass) ? v.pk : v }
        values.each do |v|
          next if v.nil?

          v, pk = [v, pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }

          Ink::R.update(self.foreign_key_table).
            set("`#{self.update_key}`=#{v}").
            where("`#{@klass.primary_key}`=#{pk}").execute
        end
      end
    end
  end
end

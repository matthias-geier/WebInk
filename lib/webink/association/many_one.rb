
module Ink
  module Association
    class ManyOne < Associations
      def foreign_key_table
        return @related_klass.table_name
      end

      def update_key
        return @klass.foreign_key
      end

      def find_references(pk, &blk)
        super(pk, @related_klass.primary_key, @klass.foreign_key, &blk)
      end

      def delete_all_associations(pk)
        Ink::R.update(self.foreign_key_table).
          set("#{self.update_key}=NULL").
          where("#{@klass.foreign_key}=#{pk}").execute
      end

      def assign_all_associations(pk, value)
        values = [value].flatten.map{ |v| v.is_a?(@related_klass) ? v.pk : v }
        values.each do |v|
          next if v.nil?

          v, pk = [v, pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }

          Ink::R.update(self.foreign_key_table).
            set("#{self.update_key}=#{pk}").
            where("#{@related_klass.primary_key}=#{v}").execute
        end
      end
    end
  end
end

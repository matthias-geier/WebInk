
module Ink
  module Association
    class ManyMany < Associations
      def foreign_key_table
        return self.join_table
      end

      def update_key
        return @klass.foreign_key
      end

      def tables_for_create
        return [] unless self.ordered_tables.first == @klass
        tables = []
        tables << Ink::R.create.table(self.join_table)._! do |s|
          cols = []
          cols << Ink::Database.database.primary_key_autoincrement.join(' ')
          cols += self.ordered_tables.map do |klass|
            "#{klass.foreign_key} #{klass.foreign_key_type}"
          end
          next cols.join(',')
        end.to_sql

        return tables
      end

      def find_references(pk, &blk)
        super(pk, @related_klass.foreign_key, @klass.foreign_key, &blk)
      end

      def delete_all_associations(pk)
        Ink::R.delete.from(self.foreign_key_table).
          where("#{@klass.foreign_key}=#{pk}").execute
      end

      def assign_all_associations(pk, value)
        values = [value].flatten.map{ |v| v.is_a?(@related_klass) ? v.pk : v }
        values.each do |v|
          next if v.nil?

          vals = [v, pk].map{ |val| Ink::SqlAdapter.transform_to_sql(val) }
          foreign_keys = [@related_klass.foreign_key, @klass.foreign_key]

          Ink::R.insert.into(self.foreign_key_table).
            _!(foreign_keys.join(',')).values._!(vals.join(',')).execute
        end
      end
    end
  end
end

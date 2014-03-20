
module Ink
  module Association
    class Associations
      def initialize(klass, related_klass)
        unless klass.is_a?(Ink::Model)
          klass = klass.to_s.constantize
        end
        unless related_klass.is_a?(Ink::Model)
          related_klass = related_klass.to_s.constantize
        end

        @klass = klass
        @related_klass = related_klass
      end

      # Public instance method
      #
      # Orders the klass and related klass by table_name and
      # returns a sorted array of both classes.
      # [returns:] Ordered array of both classes
      def ordered_tables
        return [@klass, @related_klass].sort do |a, b|
          a.table_name <=> b.table_name
        end
      end

      # Public instance method
      #
      # Generates a join table name for klass and related klass.
      # [returns:] join table name string
      def join_table
        return [@klass, @related_klass].map(&:table_name).sort.join('_')
      end

      # Public instance method
      #
      # Returns the table where the foreign key is located for an
      # association.
      # [returns:] table name
      def foreign_key_table
        return ""
      end

      # Public instance method
      #
      # Returns the foreign key name which must be updated
      # when cleaning up or assigning associations.
      # [returns:] foreign key name
      def update_key
        return ""
      end

      def foreign_fields_for_create
        return []
      end

      def tables_for_create
        return []
      end

      def find_references(pk, select_key, where_key, &blk)
        pk = Ink::SqlAdapter.transform_to_sql(pk)
        return @related_klass.find do |s|
          s.where("`#{@related_klass.primary_key}`").in! do |sub|
            sub.select("`#{select_key}`").from(self.foreign_key_table).
              where("`#{where_key}`=#{pk}")
          end

          if block_given?
            s.and!{ |sub| blk.call(sub) }
          end

          next s
        end
      end

      def delete_all_associations(pk)
        return
      end

      def assign_all_associations(pk, value)
        return
      end
    end
  end
end

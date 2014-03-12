
module Ink
  module R
    class RelationString
      def execute(connection=Ink::Database.database, as=Hash, &blk)
        connection.query(self.to_sql, as, &blk)
      end

      def to_a(connection=Ink::Database.database)
        self.execute(connection, Array){ |itm, k, v| itm << v }
      end

      def to_h(connection=Ink::Database.database)
        self.execute(connection)
      end
    end
  end
end

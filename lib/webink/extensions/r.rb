
module Ink
  module R

    # = RelationString class extension
    #
    # It provides a handy executor mechanic for the webink framework.
    # Any sql can be built and executed with the usual
    # Ink::Database.database.query logic, only with less code.
    #
    # == Equivalency
    #
    #   builder = Ink::R.select('*').from(:foobar)
    #
    #   builder.execute
    #   # equals
    #   Ink::Database.database.query(builder.to_sql)
    #
    # == Hashes
    #
    # The default return value of a query is a hash, so the #to_h method
    # is just an alias for #execute
    #
    # == Arrays
    #
    # All queries can be reduced into any object, so #to_a is an alias for
    #
    #   Ink::Database.database.query(query, Array){ |a, k, v| a << v }
    #
    #
    #
    #
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

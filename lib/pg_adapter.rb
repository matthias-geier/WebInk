module Ink

  class PgAdapter < SqlAdapter

    def initialize(config)
      @type = config[:db_type]
      @db = PG.connect({ :host => config[:db_server],
        :port => config[:db_port],
        :dbname => config[:db_database],
        :user => config[:db_user],
        :password => config[:db_pass] })
    end

    def tables
      return @db.exec("SELECT table_name FROM information_schema.tables " +
        "WHERE table_schema = 'public'").values.map(&:first)
    end

    def query(query, type=Hash, &blk)
      type = Hash unless block_given?
      result = []
      re = @db.exec(query)
      if re
        keys = re.fields
        re.each_row do |row|
          result.push(type.new)
          row.each_index do |i|
            k = keys[i]
            v = self.class.transform_from_sql(row[i])
            if block_given?
              yield(result[result.length-1], k, v)
            else
              result[result.length-1][k] = v
            end
          end
        end
      end
      return result
    end

    def transaction(commit=true, &blk)
      @db.query("BEGIN TRANSACTION")
      blk.call
      @db.query(commit ? "COMMIT" : "ROLLBACK")
    end

    def close
      @db.close
      @db = nil
    end

    def primary_key_autoincrement(pk='id')
      return [pk, "SERIAL", "PRIMARY KEY"]
    end

  end
end

module Ink

  class MysqlAdapter

    def initialize(config)
      @type = config[:db_type]
      @db = Mysql.real_connect(config[:db_server],config[:db_user],
        config[:db_pass],config[:db_database])
      @db.reconnect = true
    end

    def tables
      result = Array.new
      re = @db.query "show tables;"
      re.each do |row|
        row.each do |t|
          result.push t
        end
      end
      return result
    end

    def query(query, type=Hash)
      type = Hash if not block_given?
      result = Array.new
      re = @db.method("query").call query
      if re
        keys = re.fetch_fields.map(&:name)
        re.each do |row|
          result.push type.new
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

    def primary_key_autoincrement(pk="id")
      ["`#{pk}`", "INTEGER", "PRIMARY KEY", "AUTO_INCREMENT"]
    end

  end

end

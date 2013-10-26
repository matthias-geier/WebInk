module Ink

  class Sqlite3Adapter < SqlAdapter

    def initialize(config)
      @type = config[:db_type]
      @db = SQLite3::Database.new(config[:db_server])
    end

    def tables
      result = Array.new
      re = @db.query <<QUERY
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;
QUERY
      re.each do |row|
        row.each do |t|
          result.push t
        end
      end
      re.close
      return result
    end

    def query(query, type=Hash)
      type = Hash if not block_given?
      result = Array.new
      re = @db.method("query").call query
      re.each do |row|
        result.push type.new
        re.columns.each_index do |i|
          row[i] = self.class.transform_from_sql(row[i])
          if block_given?
            yield(result[result.length-1], re.columns[i], row[i])
          else
            result[result.length-1][re.columns[i]] = row[i]
          end
        end
      end
      re.close if not re.closed?
      return result
    end

    def close
      return if @db.closed?
      begin
        @db.close
      rescue SQLite3::BusyException
      end
      @db = nil
    end

    def primary_key_autoincrement(pk="id")
      ["`#{pk}`", "INTEGER", "PRIMARY KEY", "ASC"]
    end

  end

end

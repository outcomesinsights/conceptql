module ConceptQL
  class TempTable
    attr :name, :query
    def initialize(name, query)
      @name = name
      @query = query
    end

    def build(db)
      puts "BUILDING #{ name }"
      db.create_table!(name, as: query, temp: true)
    end

    def sql(db)
      db[db.send(:create_table_as_sql, name, query.sql, temp: true)].sql
    end
  end
end

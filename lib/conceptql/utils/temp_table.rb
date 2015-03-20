module ConceptQL
  class TempTable
    attr :name, :query, :description
    def initialize(name, opts)
      @name = name
      @query = opts[:query]
      @description = opts[:description]
    end

    def build(db)
      @built ||= build_it(db)
    end

    def build_it(db)
      db.create_table!(name, as: query, temp: true)
      true
    end

    def sql(db)
      sql = db[db.send(:create_table_as_sql, name, query.sql, temp: true)].sql
      ["-- #@description ", sql].join("\n")
    end
  end
end

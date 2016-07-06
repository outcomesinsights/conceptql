module ConceptQL
  class Database
    attr :db

    def initialize(db, opts={})
      @db = db
      db.extension :date_arithmetic
      @opts = opts.dup
      @opts[:data_model] ||= :omopv4
      @opts[:db_type] ||= db.database_type
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end
  end
end

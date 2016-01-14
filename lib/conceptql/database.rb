module ConceptQL
  class Database
    attr :db

    def initialize(db, opts={})
      @db = db
      @opts = opts.dup
      @opts[:data_model] ||= :omopv4
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end
  end
end

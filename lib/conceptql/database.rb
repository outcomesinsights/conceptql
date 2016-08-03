require 'facets/hash/revalue'

module ConceptQL
  class Database
    attr :db

    def initialize(db, opts={})
      @db = db
      db_type = :impala
      if db
        db.extension :date_arithmetic
        db.extension :error_sql
        db_type = db.database_type
      end
      @opts = opts.revalue { |v| v ? v.to_sym : v }
      @opts[:data_model] ||= :oi_cdm
      @opts[:db_type] ||= db_type
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end
  end
end

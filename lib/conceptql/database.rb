require 'facets/hash/revalue'

module ConceptQL
  class Database
    attr :db, :opts

    def initialize(db, opts={})
      @db = db
      db_type = :impala
      if db
        db.extension :date_arithmetic
        db.extension :error_sql
        db_type = db.database_type.to_sym
      end
      @opts = opts.revalue { |v| v ? v.to_sym : v }
      @opts[:data_model] ||= :omopv4
      @opts[:database_type] ||= db_type
      if db_type == :impala
        opts = { runtime_filter_mode: "OFF" }
        if mem_limit = ENV['IMPALA_MEM_LIMIT']
          opts.merge!(mem_limit: mem_limit)
        end
        db.set(opts)
      end
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end
  end
end

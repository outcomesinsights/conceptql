require 'facets/hash/revalue'

module ConceptQL
  class Database
    attr :db, :opts

    def initialize(db, opts={})
      @db = db
      db_type = :impala
      if db
        extensions.each do |extension|
          db.extension extension
        end
        db_type = db.database_type.to_sym
      end

      @opts = opts.revalue { |v| v ? v.to_sym : v }
      @opts[:data_model] ||= :omopv4
      @opts[:database_type] ||= db_type
      db.set(db_opts) if db.respond_to?(:set)
    end

    def query(statement, opts={})
      Query.new(db, statement, @opts.merge(opts))
    end

    def db_opts
      db_opts = {}
      if opts[:database_type] == :impala
        db_opts.merge!(runtime_filter_mode: "OFF")
        if mem_limit = (opts[:impala_mem_limit] || ENV['IMPALA_MEM_LIMIT'])
          db_opts.merge!(mem_limit: mem_limit)
        end
      end
      db_opts
    end

    def extensions
      [:date_arithmetic, :error_sql]
    end
  end
end

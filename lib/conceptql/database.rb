require 'facets/hash/revalue'
require 'facets/hash/symbolize_keys'

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

      @opts = opts.revalue { |v| v ? v.to_sym : v }.symbolize_keys
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
        if request_pool = (opts[:impala_db_opt_request_pool] || ENV['IMPALA_DB_OPT_REQUEST_POOL'])
          db_opts.merge!(request_pool: request_pool)
        end

        if runtime_filter_mode = (opts[:impala_runtime_filter_mode] || ENV['IMPALA_RUNTIME_FILTER_MODE'])
          db_opts.merge!(runtime_filter_mode: runtime_filter_mode)
        end

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

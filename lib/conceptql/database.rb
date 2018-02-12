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

      # Symbolize all keys and values
      @opts = ConceptQL::Utils.rekey(opts, rekey_values: true)

      @opts[:data_model] ||= (ENV["CONCEPTQL_DATA_MODEL"] || :omopv4_plus).to_sym
      @opts[:database_type] ||= db_type
      @opts[:scope_opts] = {
        force_temp_tables: opts.fetch(:force_temp_tables, ENV["CONCEPTQL_FORCE_TEMP_TABLES"] == "true"),
        scratch_database: opts.fetch(:scratch_database, ENV["DOCKER_SCRATCH_DATABASE"])
      }.merge(opts[:scope_opts] || {})
    end

    def query(statement, opts={})
      NullQuery.new if statement.nil? || statement.empty?
      @opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(opts.delete(:scope_opts) || {})
      Query.new(db, statement, @opts.merge(opts))
    end

    def extensions
      [:date_arithmetic, :error_sql, :select_remove]
    end
  end
end

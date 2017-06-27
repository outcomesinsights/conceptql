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
      @opts = Hash[opts.map { |k,v| [k.to_sym, v ? v.to_sym : v]}]

      @opts[:data_model] ||= (ENV["CONCEPTQL_DATA_MODEL"] || :omopv4_plus).to_sym
      @opts[:database_type] ||= db_type
    end

    def query(statement, opts={})
      NullQuery.new if statement.nil? || statement.empty?
      Query.new(db, statement, @opts.merge(opts))
    end

    def extensions
      [:date_arithmetic, :error_sql]
    end
  end
end

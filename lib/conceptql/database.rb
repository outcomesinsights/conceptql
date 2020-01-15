require_relative "lexicon"

module ConceptQL
  class Database
    attr_reader :db, :opts, :dm, :rdbms
    @lexicon_mutex = Mutex.new

    EXTENSIONS = [
      :coly,
      :date_arithmetic,
      :error_sql,
      :null_dataset,
      :pg_ctas_explain,
      :pg_vacuum_table,
      :select_remove,
      :semi_join,
      :sql_comments
    ]

    def initialize(db, opts={})
      @db = db
      db_type = :postgres
      if db
        self.class.db_extensions(db)
        db_type = db.database_type.to_sym
      end

      # Symbolize all keys and values
      @opts = ConceptQL::Utils.rekey(opts, rekey_values: true)

      @opts[:data_model] ||= (ENV["CONCEPTQL_DATA_MODEL"] || ConceptQL::DEFAULT_DATA_MODEL).to_sym
      @opts[:database_type] ||= db_type
      @opts[:scope_opts] = {
        force_temp_tables: opts.fetch(:force_temp_tables, ENV["CONCEPTQL_FORCE_TEMP_TABLES"] == "true"),
        scratch_database: opts.fetch(:scratch_database, ENV["DOCKER_SCRATCH_DATABASE"])
      }.merge(opts[:scope_opts] || {})
      @opts[:scope_opts][:lexicon] = lexicon
      @rdbms = Rdbms.get(db_type)
      @dm = DataModel.get(@opts[:data_model], rdbms: @rdbms, lexicon: lexicon)
    end

    def query(statement, opts={})
      NullQuery.new if statement.nil? || statement.empty?
      @opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(opts.delete(:scope_opts) || {})
      Query.new(self, ConceptQL::Utils.rekey(statement), @opts.merge(opts))
    end

    class << self
      def db_extensions(db)
        return unless db
        EXTENSIONS.each do |extension|
          db.extension extension
        end
      end

      def lexicon_db
        @lexicon_mutex.synchronize do
          unless defined?(@lexicon_db)
            @lexicon_db = make_lexicon_db
          end
        end
        @lexicon_db
      end

      def lexicon
        @lexicon ||= Lexicon.new(lexicon_db)
      end

      def make_lexicon_db
        db_opts = {}
        if ENV["CONCEPTQL_LOG_LEXICON"]
          log_path = Pathname.new("log") + "conceptql_lexicon.log"
          log_path.dirname.mkpath
          db_opts[:logger] = Logger.new(log_path)
        end
        lexicon_db = if ENV["LEXICON_URL"]
                       Sequel.connect(ENV["LEXICON_URL"], db_opts)
                     else
                       Sequel.mock(host: :postgres)
                     end
        db_extensions(lexicon_db)
        lexicon_db
      end
    end

    def lexicon
      @lexicon ||= Lexicon.new(self.class.lexicon_db, db)
    end
  end
end

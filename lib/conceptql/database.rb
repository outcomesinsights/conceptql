require_relative "lexicon"

module ConceptQL
  class Database
    attr :db, :opts
    @lexicon_mutex = Mutex.new

    EXTENSIONS = [:date_arithmetic, :error_sql, :select_remove]

    def initialize(db, opts={})
      @db = db
      db_type = :impala
      if db
        self.class.db_extensions(db)
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
      @opts[:scope_opts][:lexicon] = lexicon
    end

    def query(statement, opts={})
      NullQuery.new if statement.nil? || statement.empty?
      @opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(opts.delete(:scope_opts) || {})
      Query.new(self, ConceptQL::Utils.rekey(statement), @opts.merge(opts))
    end

    def data_model
      @data_model ||= DataModel.get(opts[:data_model])
    end

    class << self
      def db_extensions(db)
        return unless db
        EXTENSIONS.each do |extension|
          db.extension extension
        end
      end

      def lexicon
        return unless ENV["LEXICON_URL"]
        @lexicon_mutex.synchronize do
          unless defined?(@lexicon)
            @lexicon = make_lexicon
          end
        end
        @lexicon
      end

      def make_lexicon
        db_opts = {}
        if ENV["CONCEPTQL_LOG_LEXICON"]
          log_path = Pathname.new("log") + "conceptql_lexicon.log"
          log_path.dirname.mkpath
          db_opts[:logger] = Logger.new(log_path)
        end
        db = Sequel.connect(ENV["LEXICON_URL"], db_opts)
        db_extensions(db)
        Lexicon.new(db)
      end
    end

    def lexicon
      self.class.lexicon
    end
  end
end

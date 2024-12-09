require_relative 'lexicon'

module ConceptQL
  class Database
    attr_reader :db, :opts

    @lexicon_mutex = Mutex.new

    EXTENSIONS = %i[
      cold_col
      date_arithmetic
      error_sql
      make_readyable
      null_dataset
      pg_ctas_explain
      pg_vacuum_table
      select_remove
      sql_comments
      usable
    ]

    def initialize(db, opts = {})
      @db = db
      # Symbolize all keys and values
      @opts = ConceptQL::Utils.rekey(opts, rekey_values: true)

      @opts[:data_model] ||= (ENV['CONCEPTQL_DATA_MODEL'] || ConceptQL::DEFAULT_DATA_MODEL).to_sym

      db_type = db ? db.database_type.to_sym : :postgres
      if db
        self.class.db_extensions(db, @opts[:data_model])
        db_type = db.database_type.to_sym
      end

      @opts[:database_type] ||= (ENV['CONCEPTQL_DATABASE_TYPE'] || db_type).to_sym
      @opts[:scope_opts] = {
        force_temp_tables: opts.fetch(:force_temp_tables, ENV['CONCEPTQL_FORCE_TEMP_TABLES'] == 'true'),
        scratch_database: opts.fetch(:scratch_database, ENV['DOCKER_SCRATCH_DATABASE'])
      }.merge(opts[:scope_opts] || {})
      @opts[:scope_opts][:lexicon] = lexicon
    end

    def query(statement, opts = {})
      NullQuery.new if statement.nil? || statement.empty?
      @opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(opts.delete(:scope_opts) || {})
      Query.new(self, ConceptQL::Utils.rekey(statement), @opts.merge(opts))
    end

    def data_model
      @data_model ||= DataModel.get(opts[:data_model])
    end

    def base_data_model
      data_model.base
    end

    class << self
      def db_extensions(db, data_model)
        return unless db

        EXTENSIONS.each do |extension|
          db.extension extension
        end

        db.load_schema("schemas/#{data_model}.yml")
        db.load_schema('schemas/ohdsi_vocabs.yml')
      end

      def lexicon_db
        @lexicon_mutex.synchronize do
          @lexicon_db = make_lexicon_db unless defined?(@lexicon_db)
        end
        @lexicon_db
      end

      def lexicon(db = nil)
        @lexicon ||= Lexicon.new(lexicon_db, db)
      end

      def make_lexicon_db
        db_opts = {}
        if ENV['CONCEPTQL_LOG_LEXICON']
          log_path = Pathname.new('log') + 'conceptql_lexicon.log'
          log_path.dirname.mkpath
          db_opts[:logger] = Logger.new(log_path)
        end
        lexicon_db = if ENV['LEXICON_URL']
                       Sequel.connect(ENV['LEXICON_URL'], db_opts)
                     else
                       Sequel.sqlite
                     end
        lexicon_db.extension(:date_arithmetic)
        lexicon_db
      end
    end

    def lexicon
      @lexicon ||= Lexicon.new(self.class.lexicon_db, db)
    end

    def database_type
      @opts[:database_type]
    end
  end
end

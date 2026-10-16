# frozen_string_literal: true

require 'digest'
require 'logger'
require_relative 'lexicon'

module ConceptQL
  class Database
    attr_reader :db, :opts

    @lexicon_mutex = Mutex.new

    EXTENSIONS = %i[
      date_arithmetic
      error_sql
      make_readyable
      null_dataset
      pg_ctas_explain
      pg_vacuum_table
      smart_select_remove
      sql_comments
      usable
    ].freeze

    def initialize(db, opts = {})
      @db = db
      # Symbolize all keys and values
      @opts = ConceptQL::Utils.rekey(opts, rekey_values: true)

      @opts[:data_model] ||= (ENV['CONCEPTQL_DATA_MODEL'] || ConceptQL::DEFAULT_DATA_MODEL).to_sym

      self.class.db_extensions(db, @opts[:data_model], @opts[:use_cold_col])
      db_type = db ? db.database_type.to_sym : :postgres

      @lexicon = opts[:lexicon]
      if @lexicon && @opts[:cache_lookups]
        raise ArgumentError, 'cache_lookups needs the Database to build its own Lexicon; do not pass lexicon:'
      end

      @opts[:database_type] ||= (ENV['CONCEPTQL_DATABASE_TYPE'] || db_type).to_sym
      @opts[:scope_opts] = {
        force_temp_tables: opts.fetch(:force_temp_tables, ENV['CONCEPTQL_FORCE_TEMP_TABLES'] == 'true'),
        scratch_database: opts.fetch(:scratch_database, ENV['DOCKER_SCRATCH_DATABASE'])
      }.merge(opts[:scope_opts] || {})
      @opts[:scope_opts][:lexicon] = lexicon

      @shared_utilization_tables = {}
      @shared_utilization_mutex = Mutex.new
    end

    def query(statement, opts = {})
      opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(opts.delete(:scope_opts) || {})
      if @opts[:share_utilization] && opts[:scope_opts][:table_prefix].to_s.empty?
        raise ArgumentError, 'share_utilization needs a table_prefix in scope_opts, to name its tables'
      end

      Query.new(self, ConceptQL::Utils.rekey(statement), @opts.merge(opts))
    end

    def data_model
      @data_model ||= DataModel.get(opts[:data_model], nodifier: nodifier)
    end

    def nodifier
      @nodifier ||= Nodifier.new(self)
    end

    def base_data_model
      data_model.base
    end

    class << self
      def db_extensions(db, data_model, use_cold_col)
        return unless db

        EXTENSIONS.each do |extension|
          db.extension extension
        end

        use_cold_col = db.is_a?(Sequel::Mock::Database) if use_cold_col.nil?
        return unless use_cold_col

        db.extension(:cold_col)
        db.load_schema(ConceptQL.schemas_dir / "#{data_model}.yml")
        db.load_schema(ConceptQL.schemas_dir / 'ohdsi_vocabs.yml')
      end

      def lexicon_db
        @lexicon_mutex.synchronize do
          @lexicon_db = make_lexicon_db unless defined?(@lexicon_db)
        end
        @lexicon_db
      end

      # The LEXICON_URL database, or nil when it is unset. Lexicon tries the
      # data db first and, when neither has the vocabulary tables, falls back
      # to LexiconNoDB, so no database (and no sqlite3 gem) is needed here.
      def make_lexicon_db
        return unless ENV['LEXICON_URL']

        db_opts = {}
        if ENV['CONCEPTQL_LOG_LEXICON']
          log_path = Pathname.new('log') / 'conceptql_lexicon.log'
          log_path.dirname.mkpath
          db_opts[:logger] = Logger.new(log_path)
        end
        lexicon_db = Sequel.connect(ENV['LEXICON_URL'], db_opts)
        lexicon_db.extension(:date_arithmetic)
        lexicon_db
      end
    end

    def lexicon
      @lexicon ||= Lexicon.new(self.class.lexicon_db, db, cache: @opts[:cache_lookups])
    end

    # This Database's operators for a data model, as a frozen name => class
    # Hash: a vocabulary operator for every vocabulary in config/vocabularies.csv
    # (plus the custom file) and in this Database's lexicon, with the built-in
    # operators merged over them. A built-in wins a name clash (gender, race and
    # ethnicity are also vocabularies). Built lazily, once per data model.
    #
    # The data model is an argument because a Nodifier can be given one that
    # differs from this Database's.
    def operators(data_model = opts[:data_model])
      data_model = data_model.to_sym
      @operators ||= {}
      @operators[data_model] ||= begin
        vocabulary_operators = Vocabularies::DynamicVocabularies.new(lexicon).operators(data_model)
        vocabulary_operators.merge(Operators.static_operators.fetch(data_model)).freeze
      end
    end

    # Builds the table that the name_concepts_table option names. It holds
    # the concept rows whose ids appear in the data columns that the
    # display-name joins read, so those joins hash a small table instead of
    # the whole concept table. The caller drops it.
    def create_name_concepts_table
      table = opts[:name_concepts_table]
      raise ArgumentError, 'create_name_concepts_table needs the name_concepts_table option' unless table

      ids = data_model.name_concept_columns.flat_map do |source, columns|
        next [] unless db.table_exists?(source)

        (columns & db[source].columns).map { |column| db[source].exclude(column => nil).select(Sequel.as(column, :id)) }
      end
      raise ArgumentError, "no data columns to read for data model #{opts[:data_model]}" if ids.empty?

      db.create_table(table, as: data_model.concepts_table(db).where(id: ids.reduce { |all, one| all.union(one) }))
    end

    # The share_utilization option: the name of the table that holds a
    # Utilizable operator's list (its select_it(query(db)), passed as key).
    # The key's SQL contains the window table and adjustments, so two
    # different windows get two tables.
    def shared_utilization_table(key, scope)
      name = Sequel.identifier("#{scope.opts[:table_prefix]}_util_#{Digest::MD5.hexdigest(key.sql)[0, 16]}")
      scope.scratch_database.to_s.empty? ? name : name.qualify(scope.scratch_database)
    end

    # Creates a shared_utilization_table from its key, once per key, when a
    # query first reads rows. Another thread that reads the same key waits
    # here and then reads the table that the first thread created.
    def create_shared_utilization_table(name, key, rdbms, scope)
      sql = key.sql
      @shared_utilization_mutex.synchronize do
        next if @shared_utilization_tables.key?(sql)

        db.create_table(name, rdbms.create_options(scope, key).merge(as: key))
        rdbms.post_create(db, name)
        @shared_utilization_tables[sql] = name
      end
    end

    # The tables that the share_utilization option created. conceptql never
    # drops them: the caller does.
    def shared_tables
      @shared_utilization_mutex.synchronize { @shared_utilization_tables.values }
    end

    def database_type
      @opts[:database_type]
    end

    def type_for(column_name)
      Scope::COLUMN_TYPES.fetch(column_name)
    end
  end
end

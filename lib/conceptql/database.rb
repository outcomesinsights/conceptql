# frozen_string_literal: true

require "digest"
require "logger"
# Database#db_extensions names Sequel::Mock::Database before any mock exists
require "sequel/adapters/mock"
require_relative "lexicon"

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

      @opts[:data_model] ||= (ENV["CONCEPTQL_DATA_MODEL"] || ConceptQL::DEFAULT_DATA_MODEL).to_sym
      ConceptQL::DataModel.assert_supported!(@opts[:data_model])

      self.class.db_extensions(db, @opts[:data_model], @opts[:use_cold_col])
      db_type = db ? db.database_type.to_sym : :postgres

      @lexicon = opts[:lexicon]
      if @lexicon && @opts[:cache_lookups]
        raise ArgumentError, "cache_lookups needs the Database to build its own Lexicon; do not pass lexicon:"
      end
      @reference_lexicon = opts[:reference_lexicon] if opts[:reference_lexicon]

      @opts[:database_type] ||= (ENV["CONCEPTQL_DATABASE_TYPE"] || db_type).to_sym
      @opts[:scope_opts] = {
        force_temp_tables: opts.fetch(:force_temp_tables, ENV["CONCEPTQL_FORCE_TEMP_TABLES"] == "true"),
        scratch_database: opts.fetch(:scratch_database, ENV["DOCKER_SCRATCH_DATABASE"])
      }.merge(rekey_scope_opts(opts[:scope_opts]))
      @opts[:scope_opts][:lexicon] = lexicon

      @shared_utilization_tables = {}
      @shared_utilization_mutex = Mutex.new
      @source_tables = {} if @opts[:cache_lookups]
    end

    def query(statement, opts = {})
      opts[:scope_opts] = (@opts[:scope_opts] || {}).merge(rekey_scope_opts(opts.delete(:scope_opts)))
      if @opts[:share_utilization] && opts[:scope_opts][:table_prefix].to_s.empty?
        raise ArgumentError, "share_utilization needs a table_prefix in scope_opts, to name its tables"
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
        db.load_schema(ConceptQL.schemas_dir / "ohdsi_vocabs.yml")
      end

      def lexicon_db
        @lexicon_mutex.synchronize do
          @lexicon_db = make_lexicon_db unless defined?(@lexicon_db)
        end
        @lexicon_db
      end

      # The LEXICON_URL database, or nil when it is unset. Lexicon tries the
      # data db first. When neither has the vocabulary tables, a real data db
      # raises Lexicon::NoVocabularyError, and a db-less Database (db nil or a
      # Sequel mock) falls back to LexiconNoDB, so no database (and no sqlite3
      # gem) is needed here.
      def make_lexicon_db
        return unless ENV["LEXICON_URL"]

        db_opts = {}
        if ENV["CONCEPTQL_LOG_LEXICON"]
          log_path = Pathname.new("log") / "conceptql_lexicon.log"
          log_path.dirname.mkpath
          db_opts[:logger] = Logger.new(log_path)
        end
        lexicon_db = Sequel.connect(ENV["LEXICON_URL"], db_opts)
        lexicon_db.extension(:date_arithmetic)
        lexicon_db
      end
    end

    # Whether a data model's source table exists in db. With cache_lookups on,
    # a table that exists is remembered per db and table for the life of this
    # Database, as the Lexicon keeps its lookups. A missing table is checked
    # again on every call: Sequel's table_exists? also answers false on a
    # database error, and one transient error must not turn off the database
    # checks for the whole export. Only the data model's fixed source tables
    # come here, never a table that conceptql creates during a run.
    def source_table_exists?(db, table)
      return db.table_exists?(table) unless @source_tables

      key = [ db, table ]
      @source_tables.fetch(key) { db.table_exists?(table) && (@source_tables[key] = true) }
    end

    # The Lexicon passed as lexicon:, or one built from the data db and the
    # LEXICON_URL database. Database.new calls it, so a real data db without
    # vocabulary tables raises Lexicon::NoVocabularyError there.
    def lexicon
      @lexicon ||= Lexicon.new(self.class.lexicon_db, db, cache: @opts[:cache_lookups])
    end

    # The reference lexicon: the full lexicon, beside the lexicon of the
    # dataset (#lexicon), which can be trimmed to the codes that the data
    # contains (bead conceptql-8oim, seed conceptql-d9w). Only the code checks
    # (#check_codes) read it: a code that the dataset's lexicon does not know
    # is "not present in this dataset" when the reference lexicon knows it,
    # and an unknown code when it does not. Code-to-concept
    # translation, the SQL and the counts use #lexicon only. The vocabulary
    # operators are built from both, so an operator is valid whatever the
    # dataset contains.
    #
    # It is the reference_lexicon: option, or else, when LEXICON_URL is set,
    # a Lexicon of the LEXICON_URL database (Database.lexicon_db) with its own
    # cache. It is nil when neither exists. A LEXICON_URL database without
    # vocabulary tables raises.
    def reference_lexicon
      return @reference_lexicon if defined?(@reference_lexicon)

      @reference_lexicon = (lexicon_url_lexicon(self.class.lexicon_db) if self.class.lexicon_db)
    end

    # The code check that every operator with codes calls (bead
    # conceptql-dufi, seed conceptql-d9w). It returns [not_present, unknown]:
    # of the codes that #lexicon does not know in any of the vocabularies,
    # those that #reference_lexicon knows in any of them, and the rest. The
    # caller gives "code(s) not present in this dataset" for the first and
    # "unknown code(s)" for the second.
    #
    # The 2020 rule (refs #185): when no lexicon of the Database has a
    # concept of any of the vocabularies, every code is accepted and both
    # lists are empty. A lexicon that lacks a vocabulary cannot tell a real
    # code from a typo. So with a reference lexicon, the rule applies only
    # when both lexicons lack the vocabularies, and without one, when
    # #lexicon lacks them. etl_vocabulary_ids does not change the rule.
    #
    # A code matches in its own case: a statement warns about a code in
    # another case instead of raising CodeCaseMismatchError.
    def check_codes(data_db, vocabulary_ids, codes)
      vocabulary_ids = Array(vocabulary_ids).uniq
      missing = codes - known_codes_in(lexicon, data_db, vocabulary_ids, codes)
      return [ [], [] ] if missing.empty?

      lexicons = [ lexicon, reference_lexicon ].compact
      return [ [], [] ] if lexicons.all? { |lex| vocabulary_ids.all? { |id| lex.vocabulary_is_empty?(data_db, id) } }

      not_present = reference_lexicon ? known_codes_in(reference_lexicon, data_db, vocabulary_ids, missing) : []
      [ missing & not_present, missing - not_present ]
    end

    # The codes that a lexicon has in any of the vocabularies, with no
    # exception for an empty vocabulary.
    def known_codes_in(lex, data_db, vocabulary_ids, codes)
      vocabulary_ids.flat_map do |vocabulary_id|
        lex.known_codes(data_db, vocabulary_id, codes, check_case: false, empty_means_known: false)
      end.uniq
    end
    private :known_codes_in

    def lexicon_url_lexicon(lexicon_db)
      reference = Lexicon.new(lexicon_db, nil, cache: true)
      return reference unless reference.strategy == :no_db

      raise Lexicon::NoVocabularyError, "the LEXICON_URL database has no vocabulary tables, " \
                                        "so it cannot be the reference lexicon"
    end
    private :lexicon_url_lexicon

    # The scope options of a calling program with Symbol keys, as every
    # reader of the scope expects them. A program that builds its options
    # from JSON has String keys, and a String key had no effect. The keys of
    # the window_opts hash are rekeyed too. The values do not change: a
    # window table statement is rekeyed where it is queried, as the window
    # options of a window statement are (Utils.rekey of the statement).
    def rekey_scope_opts(scope_opts)
      symbolize = ->(hash) { hash.transform_keys { |key| key.respond_to?(:to_sym) ? key.to_sym : key } }
      symbolize.call(scope_opts || {}).tap do |opts|
        opts[:window_opts] = symbolize.call(opts[:window_opts]) if opts[:window_opts].is_a?(Hash)
      end
    end
    private :rekey_scope_opts

    # This Database's operators for a data model, as a frozen name => class
    # Hash: a vocabulary operator for every vocabulary in config/vocabularies.csv
    # (plus the custom file), in this Database's lexicon and in its reference
    # lexicon, with the built-in operators merged over them. A built-in wins a
    # name clash (gender, race and ethnicity are also vocabularies). Built
    # lazily, once per data model.
    #
    # The data model is an argument because a Nodifier can be given one that
    # differs from this Database's.
    def operators(data_model = opts[:data_model])
      data_model = data_model.to_sym
      ConceptQL::DataModel.assert_supported!(data_model)
      @operators ||= {}
      @operators[data_model] ||= begin
        vocabulary_operators = Vocabularies::DynamicVocabularies.new(lexicon, reference_lexicon).operators(data_model)
        vocabulary_operators.merge(Operators.static_operators.fetch(data_model)).freeze
      end
    end

    # Builds the table that the name_concepts_table option names. It holds
    # the concept rows whose ids appear in the data columns that the
    # display-name joins read, so those joins hash a small table instead of
    # the whole concept table. The caller drops it.
    def create_name_concepts_table
      table = opts[:name_concepts_table]
      raise ArgumentError, "create_name_concepts_table needs the name_concepts_table option" unless table

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
    # different windows get two tables. The name is a Symbol, because
    # sequel-duckdb's table_exists? reads a Sequel::SQL::Identifier wrong.
    def shared_utilization_table(key, scope)
      name = :"#{scope.opts[:table_prefix]}_util_#{Digest::MD5.hexdigest(key.sql)[0, 16]}"
      scope.scratch_database.to_s.empty? ? name : Sequel.qualify(scope.scratch_database.to_sym, name)
    end

    # The sql_statements entry that creates a shared_utilization_table, or nil
    # when the table exists. The caller runs the entries in order. Nothing is
    # claimed: every call lists a table until it exists.
    def shared_utilization_statement(name, key)
      return if db.table_exists?(name)

      @shared_utilization_mutex.synchronize { @shared_utilization_tables[key.sql] = name }
      [ name, key.sql ]
    end

    # Creates a shared_utilization_table that does not exist yet, when a
    # query first reads rows through conceptql. Another thread that reads the
    # same table waits here and then reads the table the first thread created.
    def create_shared_utilization_table(name, key, rdbms, scope)
      @shared_utilization_mutex.synchronize do
        next if db.table_exists?(name)

        db.create_table(name, rdbms.create_options(scope, key).merge(as: key))
        rdbms.post_create(db, name)
        @shared_utilization_tables[key.sql] = name
      end
    end

    # The shared tables that conceptql listed in sql_statements or created.
    # conceptql never drops them: the caller does.
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

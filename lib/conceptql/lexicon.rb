# frozen_string_literal: true

require "forwardable"
require_relative "code_case_mismatch_error"
require_relative "lexicon/lexicon_gdm"
require_relative "lexicon/lexicon_no_db"
require_relative "lexicon/lexicon_ohdsi"

module ConceptQL
  class Lexicon
    extend Forwardable

    # Lookups that return plain values. With cache: true each result is kept
    # for the life of this Lexicon, which is the life of its Database, so the
    # cache never outlives one export (seed conceptql-a5f). Methods that return
    # datasets are not cached: their query runs later, in the caller.
    CACHED_LOOKUPS = %i[
      code_meanings
      concept_codes
      concept_ids
      concept_ids_by_name
      concepts_to_codes
      concepts_to_codes_in_class
      descendants_of
      known_codes
      related_concept_ids
      table_is_missing?
      vocabulary_is_empty?
    ].freeze

    def_delegators :@strategy,
                   :strategy,
                   :concepts_table,
                   :concepts_by_name,
                   :vocabularies,
                   :vocabularies_query

    # The key of each lexicon kind in NoVocabularyError::Search#missing_tables.
    LEXICON_KINDS = { LexiconOhdsi => :ohdsi, LexiconGDM => :gdm }.freeze

    # The cached results keyed on [method, arguments], or nil when caching is
    # off. Its size is the number of distinct lookups.
    attr_reader :cache

    # No database that ConceptQL searched has the vocabulary tables. Without
    # them every code compiles to 1 = 0 and the unknown-code checks turn off,
    # so a query on real data would return no rows without a word.
    #
    # ConceptQL::Database raises it (through Lexicon.new) when its data
    # database is real, which is not nil and not a Sequel mock, and neither
    # that database nor the LEXICON_URL database has all the tables of one
    # lexicon kind. A database-less Database keeps LexiconNoDB.
    # MissingVocabularyError (Lexicon.for_dataset) is a subclass, so one
    # rescue covers both.
    class NoVocabularyError < StandardError
      # One database that was searched. +role+ is :data_database (the
      # Database's own db), :lexicon_url (the LEXICON_URL database) or
      # :dataset (Lexicon.for_dataset). +database+ names it without a user or
      # a password. +search_path+ is the search path that the unqualified
      # table names resolved through, or nil where the adapter has none.
      # +missing_tables+ maps each lexicon kind (:ohdsi, :gdm) that was
      # looked for to its tables that were not found.
      Search = Data.define(:role, :database, :search_path, :missing_tables)

      ROLES = {
        data_database: "the data database",
        lexicon_url: "the LEXICON_URL database",
        dataset: "the DuckDB dataset"
      }.freeze

      attr_reader :searches

      def initialize(message = nil, searches: [])
        @searches = searches
        super(message)
      end

      # The error for a ConceptQL::Database whose data database is real.
      # +database_type+ is the data database's, and chooses the advice.
      # +lexicon_url_searched+ is false when LEXICON_URL is not set.
      # +only+ is the LEXICON_*_ONLY variable that narrowed the kinds, or nil.
      def self.for_database(searches, database_type:, lexicon_url_searched:, only: nil)
        data = searches.first
        lines = [
          "ConceptQL::Database found no vocabulary tables for its data database (#{data.database}).",
          "Without them every code would match no rows and unknown codes would not be reported, " \
          "so the Database refuses to start.",
          "It searched:"
        ]
        lines.concat(searches.map { |search| "  - #{describe_search(search)}" })
        lines << "  - LEXICON_URL is not set, so no lexicon database was searched." unless lexicon_url_searched
        lines << "#{only} is set, so only the #{only.delete_prefix("LEXICON_").delete_suffix("_ONLY")} tables were looked for." if only
        lines << "Fix it in one of these ways:"
        lines.concat(advice(database_type).map { |line| "  - #{line}" })
        new(lines.join("\n"), searches: searches)
      end

      def self.describe_search(search)
        where = ROLES.fetch(search.role)
        where += " (#{search.database})" unless search.role == :data_database
        where += ", through the search path #{search.search_path.inspect}" if search.search_path
        missing = search.missing_tables.map do |kind, tables|
          "#{kind.to_s.upcase} tables #{tables.join(", ")} are missing"
        end
        "#{where}: #{missing.join("; ")}."
      end
      private_class_method :describe_search

      def self.advice(database_type)
        dataset = "Build the lexicon from the DuckDB dataset itself: " \
                  "ConceptQL::Database.new(db, lexicon: ConceptQL::Lexicon.for_dataset(db))."
        search_path = "Put the schema that holds the vocabulary tables on the data database's " \
                      "search path (in the test data, ohdsi_vocabs or gdm_vocabs)."
        lexicon_url = "Set LEXICON_URL to a database that has the vocabulary tables."
        case database_type
        when :duckdb then [ dataset, search_path, lexicon_url ]
        when :postgres then [ search_path, lexicon_url ]
        else [ lexicon_url ]
        end
      end
      private_class_method :advice
    end

    # A DuckDB dataset lacks one or more of the OHDSI vocabulary tables, so
    # Lexicon.for_dataset cannot make the dataset its own lexicon.
    class MissingVocabularyError < NoVocabularyError
      attr_reader :missing_tables, :schemas

      # +missing_tables+ are the vocabulary tables that were not found.
      # +schemas+ are the schemas that were searched for them, each as
      # "catalog.schema", and +search_path+ the DuckDB search path that the
      # unqualified table names resolved through.
      def initialize(missing_tables, schemas:, search_path:)
        @missing_tables = missing_tables
        @schemas = schemas
        search = Search.new(role: :dataset, database: "schemas #{schemas.join(", ")}",
                            search_path: search_path, missing_tables: { ohdsi: missing_tables })
        super("The DuckDB dataset (schemas #{schemas.map(&:inspect).join(", ")}) " \
              "has no vocabulary table #{missing_tables.join(", ")}. " \
              "A DuckDB dataset is its own lexicon: ConceptQL reads " \
              "#{LexiconOhdsi::VOCABULARY_TABLES.join(", ")} only from it, and never from LEXICON_URL. " \
              "The tables were looked up without a schema, through the search path #{search_path.inspect}.",
              searches: [ search ])
      end
    end

    # The lexicon of a DuckDB dataset: the OHDSI vocabulary tables of db
    # itself, found without a schema through db's search path. LEXICON_URL is
    # never read. The Lexicon caches its lookups for its own life. Pass it to
    # ConceptQL::Database.new(db, lexicon: lexicon), without cache_lookups.
    #
    # Raises MissingVocabularyError when db lacks any of the tables, because a
    # DuckDB dataset never falls back to another lexicon.
    #
    # Returns nil for a Postgres or Spark db. The caller then builds its
    # Database without lexicon:, and the Database chooses one as before.
    def self.for_dataset(db)
      return unless db.database_type.to_sym == :duckdb

      missing = LexiconOhdsi::VOCABULARY_TABLES.reject { |table| db.table_exists?(table) }
      unless missing.empty?
        search_path = db.get(Sequel.function(:current_setting, "search_path"))
        raise MissingVocabularyError.new(missing, schemas: searched_schemas(db, search_path), search_path: search_path)
      end

      new(nil, db, strategy: LexiconOhdsi.new(db), cache: true)
    end

    # The schemas, as "catalog.schema", where DuckDB looks for a table named
    # without a schema. DuckDB reports a set search path in that form. The
    # consumers attach the dataset and search, for example,
    # "memory.main,dataset_<schema>.<schema>" (sequelizer 0.5 with_dataset),
    # so current_schema() alone ("main") would name the wrong schema. With no
    # search path set, DuckDB searches the current schema (and its own system
    # schemas, which hold no dataset tables).
    def self.searched_schemas(db, search_path)
      schemas = search_path.to_s.split(",").map(&:strip).reject(&:empty?)
      return schemas unless schemas.empty?

      [ "#{db.get(Sequel.function(:current_database))}.#{db.get(Sequel.function(:current_schema))}" ]
    end
    private_class_method :searched_schemas

    def initialize(lexicon_db, dataset_db = nil, strategy: nil, cache: false)
      @strategy = strategy || determine_strategy(lexicon_db, dataset_db)
      @cache = {} if cache
    end

    (CACHED_LOOKUPS - %i[code_meanings concept_ids concepts_to_codes concepts_to_codes_in_class known_codes
                         table_is_missing?]).each do |name|
      define_method(name) do |*args|
        lookup(name, args) { @strategy.public_send(name, *args) }
      end
    end

    # The lookups below take codes. Each one raises CodeCaseMismatchError for
    # a code that matches no stored code exactly but matches one in another
    # case (bead conceptql-rz8s). A vocabulary operator passes
    # check_case: false, because a statement warns about such a code instead.

    def concept_ids(data_db, vocabulary_id, codes = [], check_case: true)
      ids = lookup(:concept_ids, [ data_db, vocabulary_id, codes ]) do
        @strategy.concept_ids(data_db, vocabulary_id, codes)
      end
      check_case!(data_db, vocabulary_id, codes) if check_case
      ids
    end

    # The datasets are not cached, but the check runs when they are built.
    def concepts(data_db, vocabulary_id, codes = [], check_case: true)
      ds = @strategy.concepts(data_db, vocabulary_id, codes)
      check_case!(data_db, vocabulary_id, codes) if check_case
      ds
    end

    def concepts_ds(data_db, vocabulary_id, codes, check_case: true)
      ds = @strategy.concepts_ds(data_db, vocabulary_id, codes)
      check_case!(data_db, vocabulary_id, codes) if check_case
      ds
    end

    # The strategy's known_codes first asks whether the vocabulary is empty.
    # It asks through the block, so that question also reaches the cache.
    def known_codes(data_db, vocabulary_id, codes, check_case: true)
      known = lookup(:known_codes, [ data_db, vocabulary_id, codes ]) do
        @strategy.known_codes(data_db, vocabulary_id, codes) { vocabulary_is_empty?(data_db, vocabulary_id) }
      end
      check_case!(data_db, vocabulary_id, Array(codes) - known) if check_case
      known
    end

    # The strategy's concepts_to_codes first asks whether the concept table is
    # missing. It asks through the block, so that question also reaches the cache.
    def concepts_to_codes(data_db, vocabulary_id, codes = [], check_case: true)
      found = lookup(:concepts_to_codes, [ data_db, vocabulary_id, codes ]) do
        @strategy.concepts_to_codes(data_db, vocabulary_id, codes) { table_is_missing?(data_db) }
      end
      check_case!(data_db, vocabulary_id, Array(codes) - found.map(&:first)) if check_case
      found
    end

    # Like concepts_to_codes, it asks about the concept table through the block.
    # A code of the vocabulary that is in another class is not in the answer,
    # so the check finds it in its own case and does not raise.
    def concepts_to_codes_in_class(data_db, vocabulary_id, concept_class_id, codes, check_case: true)
      found = lookup(:concepts_to_codes_in_class, [ data_db, vocabulary_id, concept_class_id, codes ]) do
        @strategy.concepts_to_codes_in_class(data_db, vocabulary_id, concept_class_id, codes) { table_is_missing?(data_db) }
      end
      check_case!(data_db, vocabulary_id, Array(codes) - Array(found).map(&:first)) if check_case
      found
    end

    # Like concepts_to_codes, it asks about the concept table through the block.
    def code_meanings(data_db, vocabulary_id, codes, check_case: true)
      meanings = lookup(:code_meanings, [ data_db, vocabulary_id, codes ]) do
        @strategy.code_meanings(data_db, vocabulary_id, codes) { table_is_missing?(data_db) }
      end
      check_case!(data_db, vocabulary_id, codes) if check_case
      meanings
    end

    # Only "the table is there" is kept. A missing table (or a database error,
    # which Sequel's table_exists? turns into "missing") is checked again on
    # the next call, so one transient error does not last the whole export.
    def table_is_missing?(data_db)
      lookup(:table_is_missing?, [ data_db ], keep: ->(missing) { !missing }) do
        @strategy.table_is_missing?(data_db)
      end
    end

    # Raises CodeCaseMismatchError when a code matches no stored code of the
    # vocabularies exactly, but matches one in another case. The caller passes
    # only the codes that its lookup did not find, when it can tell. A strategy
    # without case_variants (a test double) cannot check.
    def check_case!(data_db, vocabulary_id, codes)
      codes = Array(codes)
      return if codes.empty? || !@strategy.respond_to?(:case_variants)

      rows = lookup(:case_variants, [ data_db, vocabulary_id, codes ]) do
        @strategy.case_variants(data_db, vocabulary_id, codes)
      end
      mismatches = CodeCaseMismatchError.mismatches(codes, rows)
      raise CodeCaseMismatchError, mismatches unless mismatches.empty?
    end
    private :check_case!

    # Runs the lookup, or with caching on returns the result kept for the same
    # method and arguments. A result that keep rejects is returned, not kept.
    def lookup(name, args, keep: nil)
      return yield unless cache

      # Copy Array arguments so a caller that mutates one later cannot
      # change a key. Results are frozen so a mutation fails loudly.
      key = [ name, args.map { |arg| arg.is_a?(Array) ? arg.dup.freeze : arg } ]
      cache.fetch(key) do
        result = yield.dup.freeze
        cache[key] = result if keep.nil? || keep.call(result)
        result
      end
    end
    private :lookup

    # The first lexicon kind whose tables are all in the data db (dataset_db)
    # or else the lexicon db. When neither has them, LexiconNoDB, but only
    # for a database-less caller: a real data db raises NoVocabularyError.
    # A Sequel mock data db is not searched: it answers yes to every
    # table_exists?, so it would hide the lexicon db behind a vocabulary
    # that has no rows.
    def determine_strategy(lexicon_db, dataset_db)
      [ (dataset_db if real_database?(dataset_db)), lexicon_db ].compact.each do |db|
        lexicon_classes.each do |klass|
          next unless klass.db_has_all_vocabulary_tables?(db)

          return (klass.new(db))
        end
      end
      raise no_vocabulary_error(lexicon_db, dataset_db) if real_database?(dataset_db)

      LexiconNoDB.new(Sequel.mock(host: :postgres))
    end

    # Not nil and not a Sequel mock: the diagram renderer and SQL rendering
    # use those, and they have no vocabulary on purpose.
    def real_database?(db)
      !db.nil? && db.adapter_scheme != :mock
    end

    def no_vocabulary_error(lexicon_db, dataset_db)
      searches = [ search(:data_database, dataset_db) ]
      searches << search(:lexicon_url, lexicon_db) if lexicon_db
      only = %w[LEXICON_OHDSI_ONLY LEXICON_GDM_ONLY].find { |name| ENV[name] }
      NoVocabularyError.for_database(searches, database_type: dataset_db.database_type.to_sym,
                                               lexicon_url_searched: !lexicon_db.nil?, only: only)
    end

    def search(role, db)
      missing = lexicon_classes.to_h do |klass|
        [ LEXICON_KINDS.fetch(klass), klass::VOCABULARY_TABLES.reject { |table| db.table_exists?(table) } ]
      end
      NoVocabularyError::Search.new(role: role, database: describe_database(db),
                                    search_path: search_path_of(db), missing_tables: missing)
    end

    # The database's type, name and host, never its user or password. A
    # DuckDB database is named by its file, which DuckDB reports itself:
    # Sequel's URL parsing drops the leading "/" of a duckdb:///path.
    def describe_database(db)
      name = db.opts[:database]
      if db.database_type.to_sym == :duckdb
        name = db.from(Sequel.function(:duckdb_databases))
                 .where(database_name: Sequel.function(:current_database))
                 .get(:path) || ":memory:"
      end
      host = db.opts[:host].to_s
      [ "#{db.database_type} database",
        (name.to_s.inspect if name),
        ("on host #{host.inspect}" unless host.empty?) ].compact.join(" ")
    end

    # The search path that a table named without a schema resolves through:
    # Postgres's search_path setting, DuckDB's searched schemas as
    # "catalog.schema", or nil for an adapter without one.
    def search_path_of(db)
      case db.database_type.to_sym
      when :postgres then db.get(Sequel.function(:current_setting, "search_path"))
      when :duckdb
        self.class.send(:searched_schemas, db, db.get(Sequel.function(:current_setting, "search_path"))).join(",")
      end
    end
    private :real_database?, :no_vocabulary_error, :search, :describe_database, :search_path_of

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV["LEXICON_GDM_ONLY"]
      classes << LexiconGDM unless ENV["LEXICON_OHDSI_ONLY"]
      classes
    end
  end
end

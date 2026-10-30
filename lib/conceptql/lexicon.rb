# frozen_string_literal: true

require "forwardable"
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
                   :concepts,
                   :concepts_table,
                   :concepts_by_name,
                   :concepts_ds,
                   :vocabularies,
                   :vocabularies_query

    # The cached results keyed on [method, arguments], or nil when caching is
    # off. Its size is the number of distinct lookups.
    attr_reader :cache

    # A DuckDB dataset lacks one or more of the OHDSI vocabulary tables, so
    # Lexicon.for_dataset cannot make the dataset its own lexicon.
    class MissingVocabularyError < StandardError
      attr_reader :missing_tables, :schemas

      # +missing_tables+ are the vocabulary tables that were not found.
      # +schemas+ are the schemas that were searched for them, each as
      # "catalog.schema", and +search_path+ the DuckDB search path that the
      # unqualified table names resolved through.
      def initialize(missing_tables, schemas:, search_path:)
        @missing_tables = missing_tables
        @schemas = schemas
        super("The DuckDB dataset (schemas #{schemas.map(&:inspect).join(", ")}) " \
              "has no vocabulary table #{missing_tables.join(", ")}. " \
              "A DuckDB dataset is its own lexicon: ConceptQL reads " \
              "#{LexiconOhdsi::VOCABULARY_TABLES.join(", ")} only from it, and never from LEXICON_URL. " \
              "The tables were looked up without a schema, through the search path #{search_path.inspect}.")
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
    # consumers attach the dataset and search "memory.main,dataset.<schema>",
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

    (CACHED_LOOKUPS - %i[code_meanings concepts_to_codes concepts_to_codes_in_class known_codes table_is_missing?]).each do |name|
      define_method(name) do |*args|
        lookup(name, args) { @strategy.public_send(name, *args) }
      end
    end

    # The strategy's known_codes first asks whether the vocabulary is empty.
    # It asks through the block, so that question also reaches the cache.
    def known_codes(data_db, vocabulary_id, codes)
      lookup(:known_codes, [ data_db, vocabulary_id, codes ]) do
        @strategy.known_codes(data_db, vocabulary_id, codes) { vocabulary_is_empty?(data_db, vocabulary_id) }
      end
    end

    # The strategy's concepts_to_codes first asks whether the concept table is
    # missing. It asks through the block, so that question also reaches the cache.
    def concepts_to_codes(data_db, vocabulary_id, codes = [])
      lookup(:concepts_to_codes, [ data_db, vocabulary_id, codes ]) do
        @strategy.concepts_to_codes(data_db, vocabulary_id, codes) { table_is_missing?(data_db) }
      end
    end

    # Like concepts_to_codes, it asks about the concept table through the block.
    def concepts_to_codes_in_class(data_db, vocabulary_id, concept_class_id, codes)
      lookup(:concepts_to_codes_in_class, [ data_db, vocabulary_id, concept_class_id, codes ]) do
        @strategy.concepts_to_codes_in_class(data_db, vocabulary_id, concept_class_id, codes) { table_is_missing?(data_db) }
      end
    end

    # Like concepts_to_codes, it asks about the concept table through the block.
    def code_meanings(data_db, vocabulary_id, codes)
      lookup(:code_meanings, [ data_db, vocabulary_id, codes ]) do
        @strategy.code_meanings(data_db, vocabulary_id, codes) { table_is_missing?(data_db) }
      end
    end

    # Only "the table is there" is kept. A missing table (or a database error,
    # which Sequel's table_exists? turns into "missing") is checked again on
    # the next call, so one transient error does not last the whole export.
    def table_is_missing?(data_db)
      lookup(:table_is_missing?, [ data_db ], keep: ->(missing) { !missing }) do
        @strategy.table_is_missing?(data_db)
      end
    end

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

    def determine_strategy(lexicon_db, dataset_db)
      [ dataset_db, lexicon_db ].compact.each do |db|
        lexicon_classes.each do |klass|
          next unless klass.db_has_all_vocabulary_tables?(db)

          return (klass.new(db))
        end
      end
      LexiconNoDB.new(Sequel.mock(host: :postgres))
    end

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV["LEXICON_GDM_ONLY"]
      classes << LexiconGDM unless ENV["LEXICON_OHDSI_ONLY"]
      classes
    end
  end
end

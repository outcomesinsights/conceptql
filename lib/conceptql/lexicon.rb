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

    def initialize(lexicon_db, dataset_db = nil, strategy: nil, cache: false)
      @strategy = strategy || determine_strategy(lexicon_db, dataset_db)
      @cache = {} if cache
    end

    (CACHED_LOOKUPS - %i[code_meanings concepts_to_codes known_codes table_is_missing?]).each do |name|
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

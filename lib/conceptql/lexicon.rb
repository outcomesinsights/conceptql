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

    (CACHED_LOOKUPS - %i[concepts_to_codes known_codes]).each do |name|
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

    # Runs the lookup, or with caching on returns the result kept for the same
    # method and arguments.
    def lookup(name, args)
      return yield unless cache

      # Copy Array arguments so a caller that mutates one later cannot
      # change a key. Results are frozen so a mutation fails loudly.
      key = [ name, args.map { |arg| arg.is_a?(Array) ? arg.dup.freeze : arg } ]
      cache.fetch(key) { cache[key] = yield.dup.freeze }
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

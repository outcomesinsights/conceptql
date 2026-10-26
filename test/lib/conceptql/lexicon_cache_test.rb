# frozen_string_literal: true

require_relative "../../helper"
require "conceptql"

# The opt-in lookup cache (seed conceptql-a5f): a Database built with
# cache_lookups: true keeps lexicon lookup results for its own life only.
describe "ConceptQL::Lexicon lookup cache" do
  # A strategy that counts how often each lookup reaches it.
  let(:counting_strategy) do
    Class.new do
      attr_reader :calls

      def initialize
        @calls = Hash.new(0)
      end

      def concept_ids(_data_db, vocabulary_id, codes = [])
        @calls[:concept_ids] += 1
        codes.map { |code| "#{vocabulary_id}:#{code}" }
      end

      def known_codes(_data_db, _vocabulary_id, codes)
        @calls[:known_codes] += 1
        codes
      end
    end.new
  end

  it "sends a repeated lookup to the strategy once" do
    lexicon = ConceptQL::Lexicon.new(nil, strategy: counting_strategy, cache: true)

    first = lexicon.concept_ids(nil, "ICD9CM", %w[412])
    second = lexicon.concept_ids(nil, "ICD9CM", %w[412])

    _(second).must_equal first
    _(counting_strategy.calls[:concept_ids]).must_equal 1
    _(lexicon.cache.size).must_equal 1
  end

  it "keeps lookups with different arguments apart" do
    lexicon = ConceptQL::Lexicon.new(nil, strategy: counting_strategy, cache: true)

    _(lexicon.concept_ids(nil, "ICD9CM", %w[412])).must_equal [ "ICD9CM:412" ]
    _(lexicon.concept_ids(nil, "ICD9CM", %w[250])).must_equal [ "ICD9CM:250" ]
    _(counting_strategy.calls[:concept_ids]).must_equal 2
  end

  it "freezes a cached result and does not freeze the caller argument" do
    lexicon = ConceptQL::Lexicon.new(nil, strategy: counting_strategy, cache: true)
    codes = %w[412]

    result = lexicon.known_codes(nil, "ICD9CM", codes)

    _(result).must_be :frozen?
    _(codes).wont_be :frozen?
    codes << "250"

    _(lexicon.known_codes(nil, "ICD9CM", %w[412])).must_equal %w[412]
    _(counting_strategy.calls[:known_codes]).must_equal 1
  end

  it "sends every lookup to the strategy when caching is off" do
    lexicon = ConceptQL::Lexicon.new(nil, strategy: counting_strategy)

    2.times { lexicon.concept_ids(nil, "ICD9CM", %w[412]) }

    _(lexicon.cache).must_be_nil
    _(counting_strategy.calls[:concept_ids]).must_equal 2
  end

  # A real LexiconStrategy, so its own known_codes runs, with the database
  # queries replaced by counted answers from a Hash of vocabulary => codes.
  let(:vocab_strategy) do
    Class.new(ConceptQL::LexiconStrategy) do
      attr_reader :calls
      attr_accessor :failures

      def initialize(concepts)
        super(nil)
        @concepts = concepts
        @calls = Hash.new(0)
        @failures = 0
      end

      def db_is_mock?(_data_db)
        false
      end

      def vocabulary_is_empty?(_data_db, vocabulary_id)
        @calls[:vocabulary_is_empty?] += 1
        if failures.positive?
          self.failures -= 1
          raise Sequel::DatabaseError, "probe failed"
        end
        @concepts.fetch(vocabulary_id, []).empty?
      end

      def concepts_ds(_data_db, vocabulary_id, codes)
        @calls[:concepts_ds] += 1
        known = codes & @concepts.fetch(vocabulary_id, [])
        Object.new.tap { |ds| ds.define_singleton_method(:select_map) { |_column| known } }
      end

      def concept_codes(_data_db, vocabulary_id)
        @calls[:concept_codes] += 1
        Array(vocabulary_id).flat_map { |vocab| @concepts.fetch(vocab, []) }
      end

      def concept_ids_by_name(_data_db, names)
        @calls[:concept_ids_by_name] += 1
        names.map { |name| "id:#{name.downcase}" }
      end
    end.new("ICD9CM" => %w[412 250], "CPT4" => %w[99213], "EMPTY" => [])
  end

  describe "known_codes" do
    it "asks once whether a vocabulary is empty, for any number of code lists" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy, cache: true)

      _(lexicon.known_codes(nil, "ICD9CM", %w[412 999])).must_equal %w[412]
      _(lexicon.known_codes(nil, "ICD9CM", %w[250])).must_equal %w[250]

      _(vocab_strategy.calls[:vocabulary_is_empty?]).must_equal 1
      _(vocab_strategy.calls[:concepts_ds]).must_equal 2
    end

    it "asks separately for each vocabulary" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy, cache: true)

      # An empty vocabulary accepts every code; a full one checks them.
      _(lexicon.known_codes(nil, "EMPTY", %w[1 2])).must_equal %w[1 2]
      _(lexicon.known_codes(nil, "ICD9CM", %w[1 2])).must_equal []
      _(vocab_strategy.calls[:vocabulary_is_empty?]).must_equal 2

      _(lexicon.vocabulary_is_empty?(nil, "EMPTY")).must_equal true
      _(lexicon.vocabulary_is_empty?(nil, "ICD9CM")).must_equal false
      _(vocab_strategy.calls[:vocabulary_is_empty?]).must_equal 2
    end

    it "asks every time when caching is off" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy)

      2.times { _(lexicon.known_codes(nil, "ICD9CM", %w[412])).must_equal %w[412] }

      _(vocab_strategy.calls[:vocabulary_is_empty?]).must_equal 2
      _(vocab_strategy.calls[:concepts_ds]).must_equal 2
    end

    it "keeps no emptiness answer when the check fails" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy, cache: true)
      vocab_strategy.failures = 1

      # known_codes turns a database error into no known codes, as without the cache.
      _(lexicon.known_codes(nil, "ICD9CM", %w[412])).must_equal []
      _(lexicon.cache.keys.map(&:first)).wont_include :vocabulary_is_empty?

      _(lexicon.known_codes(nil, "ICD9CM", %w[250])).must_equal %w[250]
      _(vocab_strategy.calls[:vocabulary_is_empty?]).must_equal 2
    end
  end

  describe "concept_ids_by_name" do
    it "looks up each list of names once and keeps different lists apart" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy, cache: true)

      _(lexicon.concept_ids_by_name(nil, %w[White])).must_equal %w[id:white]
      _(lexicon.concept_ids_by_name(nil, %w[White])).must_equal %w[id:white]
      _(lexicon.concept_ids_by_name(nil, %w[Asian])).must_equal %w[id:asian]

      _(vocab_strategy.calls[:concept_ids_by_name]).must_equal 2
    end
  end

  describe "concept_codes" do
    it "looks up each vocabulary list once and keeps different lists apart" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: vocab_strategy, cache: true)

      _(lexicon.concept_codes(nil, %w[ICD9CM])).must_equal %w[412 250]
      _(lexicon.concept_codes(nil, %w[ICD9CM CPT4])).must_equal %w[412 250 99213]
      _(lexicon.concept_codes(nil, %w[ICD9CM])).must_equal %w[412 250]

      _(vocab_strategy.calls[:concept_codes]).must_equal 2
    end
  end

  describe "concepts_to_codes" do
    # Counts the concept-table check, and answers with no rows.
    let(:table_strategy) do
      Class.new(ConceptQL::LexiconStrategy) do
        attr_reader :calls

        def initialize
          super(:lexicon_db)
          @calls = Hash.new(0)
        end

        # The answers to give, in order; after the last one, "not missing".
        attr_accessor :missing_answers

        def table_is_missing?(_data_db)
          @calls[:table_is_missing?] += 1
          Array(missing_answers).shift || false
        end

        def concepts(_data_db, _vocabulary_id, codes = [])
          @calls[:concepts] += 1
          Object.new.tap { |ds| ds.define_singleton_method(:select_map) { |_columns| codes.map { |c| [ c, "text #{c}" ] } } }
        end
      end.new
    end

    it "checks the concept table once, for any number of code lists" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: table_strategy, cache: true)

      _(lexicon.concepts_to_codes(nil, "ICD9CM", %w[412])).must_equal [ [ "412", "text 412" ] ]
      _(lexicon.concepts_to_codes(nil, "ICD9CM", %w[250])).must_equal [ [ "250", "text 250" ] ]
      _(lexicon.concepts_to_codes(nil, "ICD9CM", %w[250])).must_equal [ [ "250", "text 250" ] ]

      _(table_strategy.calls[:table_is_missing?]).must_equal 1
      _(table_strategy.calls[:concepts]).must_equal 2
    end

    it "checks a missing concept table again, and not after it appears" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: table_strategy, cache: true)
      table_strategy.missing_answers = [ true ]

      _(lexicon.table_is_missing?(nil)).must_equal true
      _(lexicon.table_is_missing?(nil)).must_equal false
      _(lexicon.table_is_missing?(nil)).must_equal false

      _(table_strategy.calls[:table_is_missing?]).must_equal 2
    end

    it "checks the concept table every time when caching is off" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: table_strategy)

      2.times { lexicon.concepts_to_codes(nil, "ICD9CM", %w[412]) }

      _(table_strategy.calls[:table_is_missing?]).must_equal 2
      _(table_strategy.calls[:concepts]).must_equal 2
    end
  end

  # The data models ask whether their source tables exist through the
  # Database, which keeps each answer per data db and table (conceptql-q7c).
  describe "source table checks" do
    # A data db that counts table_exists? per table.
    def counting_db(*tables)
      Object.new.tap do |db|
        calls = Hash.new(0)
        db.define_singleton_method(:calls) { calls }
        db.define_singleton_method(:tables) { tables }
        db.define_singleton_method(:table_exists?) do |table|
          calls[table] += 1
          tables.include?(table)
        end
      end
    end

    def data_model(name, cache:)
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: name, cache_lookups: cache).data_model
    end

    it "checks each table of a data db once" do
      gdm = data_model(:gdm, cache: true)
      db = counting_db(:patients, :clinical_codes)

      3.times { _(gdm.table_is_missing?(db)).must_equal false }

      _(db.calls).must_equal(patients: 1, clinical_codes: 1)
    end

    it "keeps tables and data dbs apart" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm, cache_lookups: true)
      full = counting_db(:patients, :clinical_codes)
      partial = counting_db(:patients)

      2.times do
        _(cdb.data_model.table_is_missing?(full)).must_equal false
        _(cdb.data_model.table_is_missing?(partial)).must_equal true
        _(cdb.source_table_exists?(partial, :observations)).must_equal false
      end

      # Only tables that exist are remembered; missing ones are asked again.
      _(full.calls).must_equal(patients: 1, clinical_codes: 1)
      _(partial.calls).must_equal(patients: 1, clinical_codes: 2, observations: 2)
    end

    it "asks again after a missing table, and not after it appears" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide, cache_lookups: true)
      db = counting_db

      # A transient error looks the same: Sequel's table_exists? answers false.
      _(cdb.source_table_exists?(db, :observations)).must_equal false
      _(cdb.source_table_exists?(db, :observations)).must_equal false
      _(db.calls).must_equal(observations: 2)

      db.tables << :observations
      2.times { _(cdb.source_table_exists?(db, :observations)).must_equal true }
      _(db.calls).must_equal(observations: 3)
    end

    it "gives each Database its own answers" do
      db = counting_db(:observations)

      2.times { _(data_model(:gdm_wide, cache: true).table_is_missing?(db)).must_equal false }

      _(db.calls).must_equal(observations: 2)
    end

    it "checks every time when caching is off" do
      gdm_wide = data_model(:gdm_wide, cache: false)
      db = counting_db(:observations)

      2.times { _(gdm_wide.table_is_missing?(db)).must_equal false }

      _(db.calls).must_equal(observations: 2)
    end
  end

  describe "ConceptQL::Database cache_lookups" do
    it "is off by default" do
      _(ConceptQL::Database.new(Sequel.mock(host: :postgres)).lexicon.cache).must_be_nil
    end

    it "gives each Database its own cache" do
      one = ConceptQL::Database.new(Sequel.mock(host: :postgres), cache_lookups: true)
      two = ConceptQL::Database.new(Sequel.mock(host: :postgres), cache_lookups: true)

      _(one.lexicon.cache).must_equal({})
      _(one.lexicon.cache).wont_be_same_as two.lexicon.cache
    end

    it "refuses a Lexicon passed in from outside" do
      lexicon = ConceptQL::Lexicon.new(nil, strategy: counting_strategy)

      _(proc { ConceptQL::Database.new(Sequel.mock(host: :postgres), lexicon: lexicon, cache_lookups: true) })
        .must_raise ArgumentError
    end
  end
end

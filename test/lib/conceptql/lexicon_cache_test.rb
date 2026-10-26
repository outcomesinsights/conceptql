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

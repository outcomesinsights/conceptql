# frozen_string_literal: true

require_relative "../../../db_helper"

# ConceptQL::Lexicon.for_dataset: a DuckDB dataset's own OHDSI vocabulary
# tables are its lexicon, and LEXICON_URL is never read (bead conceptql-avo).
describe "ConceptQL::Lexicon.for_dataset" do
  # A db that has only the tables it is given.
  def db_with_tables(*tables)
    Object.new.tap do |db|
      db.define_singleton_method(:table_exists?) { |table| tables.include?(table) }
    end
  end

  def with_lexicon_url(url)
    old = ENV.fetch("LEXICON_URL", nil)
    ENV["LEXICON_URL"] = url
    yield
  ensure
    ENV["LEXICON_URL"] = old
  end

  def skip_unless_duckdb
    skip "needs the DuckDB fixture (just test-duckdb)" unless DB.database_type.to_sym == :duckdb
  end

  describe "LexiconOhdsi.db_has_all_vocabulary_tables?" do
    it "is true when the db has the four OHDSI vocabulary tables" do
      db = db_with_tables(:concept, :concept_ancestor, :concept_relationship, :vocabulary)

      _(ConceptQL::LexiconOhdsi.db_has_all_vocabulary_tables?(db)).must_equal true
    end

    it "is false when one of them is missing" do
      db = db_with_tables(:concept, :concept_ancestor, :vocabulary)

      _(ConceptQL::LexiconOhdsi.db_has_all_vocabulary_tables?(db)).must_equal false
    end
  end

  it "is nil for a Postgres db, so the caller chooses the lexicon as before" do
    _(ConceptQL::Lexicon.for_dataset(Sequel.mock(host: :postgres))).must_be_nil
  end

  it "is nil for a Spark db" do
    _(ConceptQL::Lexicon.for_dataset(Sequel.mock(host: :spark))).must_be_nil
  end

  it "resolves codes from the dataset's own vocabulary tables while LEXICON_URL points elsewhere" do
    skip_unless_duckdb

    with_lexicon_url("postgres://nobody@lexicon-url-must-not-be-read.invalid/nothing") do
      lexicon = ConceptQL::Lexicon.for_dataset(DB)

      _(lexicon.strategy).must_equal :ohdsi
      _(lexicon.cache).must_equal({})

      expected = DB[:concept].where(vocabulary_id: "ICD9CM", concept_code: "412").select_map(:concept_id)
      _(expected).wont_be_empty
      _(lexicon.concept_ids(DB, "ICD9CM", %w[412])).must_equal expected

      cdb = ConceptQL::Database.new(DB, data_model: CDB.opts[:data_model], lexicon: lexicon)
      _(cdb.query(%w[icd9 412]).query.count).must_be :>, 0
    end
  end

  it "resolves codes while LEXICON_URL is unset" do
    skip_unless_duckdb

    with_lexicon_url(nil) do
      lexicon = ConceptQL::Lexicon.for_dataset(DB)

      _(lexicon.concept_ids(DB, "ICD9CM", %w[412])).wont_be_empty
    end
  end

  it "raises MissingVocabularyError naming the missing tables, the schema and the search path" do
    skip_unless_duckdb

    db = Sequel.connect("duckdb::memory:")
    db.create_table(:concept) { Integer :concept_id }
    db.create_table(:vocabulary) { String :vocabulary_id }

    err = _ { ConceptQL::Lexicon.for_dataset(db) }.must_raise ConceptQL::Lexicon::MissingVocabularyError
    _(err.missing_tables).must_equal %i[concept_ancestor concept_relationship]
    _(err.message).must_include "concept_ancestor, concept_relationship"
    _(err.message).must_include 'schema "main"'
    _(err.message).must_include "search path"
    _(err.message).must_include "LEXICON_URL"
  ensure
    db&.disconnect
  end
end

# frozen_string_literal: true

require "tmpdir"
require_relative "../../../db_helper"

# A ConceptQL::Database on a real data database raises
# ConceptQL::Lexicon::NoVocabularyError when neither that database nor the
# LEXICON_URL database has the vocabulary tables (bead conceptql-brm, seed
# conceptql-ysx, option A). Before, it fell back to LexiconNoDB without a
# word: every code compiled to 1 = 0 and the unknown-code checks turned off.
# A database-less Database (db nil or a Sequel mock) keeps LexiconNoDB.
describe ConceptQL::Lexicon::NoVocabularyError do
  let(:ohdsi_tables) { "concept, concept_ancestor, concept_relationship, vocabulary" }

  # Database.lexicon_db is built once per process from LEXICON_URL, so the
  # tests replace it. A lambda, because Minitest's stub calls a value that
  # responds to call, and a Sequel::Database does.
  def with_lexicon_db(lexicon_db, &block)
    ConceptQL::Database.stub(:lexicon_db, -> { lexicon_db }, &block)
  end

  # A lexicon database that has the OHDSI vocabulary tables.
  def sqlite_lexicon_db
    Sequel.connect("sqlite:/").tap do |ldb|
      ldb.create_table(:vocabulary) do
        String :vocabulary_id
        String :vocabulary_name
      end
      ldb.create_table(:concept_ancestor) do
        Integer :ancestor_concept_id
        Integer :descendant_concept_id
      end
      ldb.create_table(:concept) do
        Integer :concept_id
        String :concept_code
        String :concept_name
        String :vocabulary_id
      end
      ldb.create_table(:concept_relationship) { String :relationship_id }
    end
  end

  def no_vocabulary_error(db)
    _ { ConceptQL::Database.new(db, data_model: :gdm) }.must_raise ConceptQL::Lexicon::NoVocabularyError
  end

  describe "a database-less Database" do
    it "keeps LexiconNoDB when db is nil" do
      with_lexicon_db(nil) do
        _(ConceptQL::Database.new(nil, data_model: :gdm).lexicon.strategy).must_equal :no_db
      end
    end

    it "keeps LexiconNoDB when db is nil and the LEXICON_URL database has no vocabulary" do
      lexicon_db = Sequel.connect("sqlite:/")
      with_lexicon_db(lexicon_db) do
        _(ConceptQL::Database.new(nil, data_model: :gdm).lexicon.strategy).must_equal :no_db
      end
    ensure
      lexicon_db&.disconnect
    end

    it "does not raise for a Sequel mock" do
      with_lexicon_db(nil) do
        _(ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm).lexicon).must_be_kind_of ConceptQL::Lexicon
      end
    end

    # conceptql-0xz: a Sequel mock answers yes to every table_exists?, so it
    # was chosen as an OHDSI vocabulary that has no rows, and the LEXICON_URL
    # database was never searched. Every lexicon vocabulary was then an
    # invalid operator.
    it "uses the LEXICON_URL database for a Sequel mock" do
      lexicon_db = sqlite_lexicon_db
      lexicon_db[:vocabulary].insert(vocabulary_id: "Lexicon Only Test", vocabulary_name: "Lexicon only test")
      with_lexicon_db(lexicon_db) do
        cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
        _(cdb.lexicon.strategy).must_equal :ohdsi
        _(cdb.lexicon.vocabularies_query.db).must_be_same_as lexicon_db
        _(cdb.operators.keys).must_include "lexicon_only_test"
        _(cdb.query([ "lexicon_only_test", "X1" ]).validation_errors).must_be_empty
      end
    ensure
      lexicon_db&.disconnect
    end

    it "uses LexiconNoDB for a Sequel mock without LEXICON_URL" do
      with_lexicon_db(nil) do
        _(ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm).lexicon.strategy).must_equal :no_db
      end
    end

    it "does not raise for a Sequel mock whose tables never exist" do
      mock = Sequel.mock(host: :postgres, fetch: proc { raise Sequel::DatabaseError, "no such table" })
      with_lexicon_db(nil) do
        _(ConceptQL::Database.new(mock, data_model: :gdm).lexicon.strategy).must_equal :no_db
      end
    end
  end

  describe "a real data database without vocabulary" do
    it "raises at Database.new, naming the database, the missing OHDSI tables and LEXICON_URL" do
      db = Sequel.connect("sqlite:/")
      err = with_lexicon_db(nil) { no_vocabulary_error(db) }

      _(err.searches.map(&:role)).must_equal %i[data_database]
      _(err.searches.first.missing_tables).must_equal(
        { ohdsi: %i[concept concept_ancestor concept_relationship vocabulary] }
      )
      _(err.message).must_include "sqlite database"
      _(err.message).must_include "OHDSI tables #{ohdsi_tables}"
      _(err.message).must_include "LEXICON_URL is not set"
      _(err.message).must_include "every code would match no rows"
    ensure
      db&.disconnect
    end

    # The GDM lexicon is removed (bead conceptql-jh58), so its four tables
    # are not a lexicon.
    it "raises for a database that has only the GDM vocabulary tables" do
      db = Sequel.connect("sqlite:/")
      %i[ancestors concepts mappings vocabularies].each { |table| db.create_table(table) { Integer :id } }
      err = with_lexicon_db(nil) { no_vocabulary_error(db) }

      _(err.searches.first.missing_tables).must_equal(
        { ohdsi: %i[concept concept_ancestor concept_relationship vocabulary] }
      )
      _(err.message).wont_include "GDM"
    ensure
      db&.disconnect
    end

    it "names the LEXICON_URL database and its missing tables when that database lacks them too" do
      db = Sequel.connect("sqlite:/")
      lexicon_db = Sequel.connect("sqlite:/")
      lexicon_db.create_table(:concept) { Integer :concept_id }
      err = with_lexicon_db(lexicon_db) { no_vocabulary_error(db) }

      _(err.searches.map(&:role)).must_equal %i[data_database lexicon_url]
      _(err.searches.last.missing_tables[:ohdsi]).must_equal %i[concept_ancestor concept_relationship vocabulary]
      _(err.message).must_include "the LEXICON_URL database"
      _(err.message).must_include "OHDSI tables concept_ancestor, concept_relationship, vocabulary"
      _(err.message).wont_include "LEXICON_URL is not set"
    ensure
      db&.disconnect
      lexicon_db&.disconnect
    end

    it "uses the LEXICON_URL database when that database has the vocabulary" do
      db = Sequel.connect("sqlite:/")
      lexicon_db = sqlite_lexicon_db
      with_lexicon_db(lexicon_db) do
        _(ConceptQL::Database.new(db, data_model: :gdm).lexicon.strategy).must_equal :ohdsi
      end
    ensure
      db&.disconnect
      lexicon_db&.disconnect
    end

    it "does not raise when the Database is given a lexicon" do
      db = Sequel.connect("sqlite:/")
      lexicon_db = sqlite_lexicon_db
      with_lexicon_db(nil) do
        cdb = ConceptQL::Database.new(db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(lexicon_db))
        _(cdb.lexicon.strategy).must_equal :ohdsi
      end
    ensure
      db&.disconnect
      lexicon_db&.disconnect
    end

    it "never prints the password of either database" do
      db = Sequel.connect("sqlite:/", user: "someone", password: "data-secret")
      lexicon_db = Sequel.connect("sqlite:/", user: "someone", password: "lexicon-secret")
      err = with_lexicon_db(lexicon_db) { no_vocabulary_error(db) }

      _(err.message).wont_include "secret"
    ensure
      db&.disconnect
      lexicon_db&.disconnect
    end

    it "raises on a real DuckDB file without vocabulary tables, and points at Lexicon.for_dataset" do
      skip "needs the duckdb gem (just test-duckdb)" unless DB.database_type.to_sym == :duckdb

      Dir.mktmpdir do |dir|
        file = File.join(dir, "no_vocabulary.duckdb")
        db = Sequel.connect("duckdb://#{file}")
        db.create_table(:patients) { Integer :id }
        err = with_lexicon_db(nil) { no_vocabulary_error(db) }

        _(err).must_be_kind_of ConceptQL::Lexicon::NoVocabularyError
        _(err.message).must_include "duckdb database"
        _(err.message).must_include file
        _(err.message).must_include "search path"
        _(err.message).must_include "no_vocabulary.main"
        _(err.message).must_include "ConceptQL::Lexicon.for_dataset(db)"
      ensure
        db&.disconnect
      end
    end

    it "raises on a real Postgres connection whose search path lacks the vocabulary" do
      skip "needs the Postgres fixture (just test)" unless DB.database_type.to_sym == :postgres

      db = Sequel.connect(DB.opts.except(:after_connect).merge(search_path: "bad_path"))
      err = with_lexicon_db(nil) { no_vocabulary_error(db) }

      _(err.message).must_include "postgres database"
      _(err.message).must_include DB.opts[:database].to_s
      _(err.message).must_include 'search path "bad_path"'
      _(err.message).must_include "OHDSI tables #{ohdsi_tables}"
      _(err.message).must_include "LEXICON_URL"
    ensure
      db&.disconnect
    end
  end

  it "is the superclass of MissingVocabularyError, so one rescue covers Lexicon.for_dataset too" do
    _(ConceptQL::Lexicon::MissingVocabularyError.ancestors).must_include ConceptQL::Lexicon::NoVocabularyError
  end
end

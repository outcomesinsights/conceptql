# frozen_string_literal: true

require_relative "db_helper"
require_relative "db"
require_relative "../lib/conceptql/query"
require_relative "../lib/conceptql/database"

describe ConceptQL::Operators do
  let(:cdb) do
    ConceptQL::Database.new(DB)
  end

  # A well-formed code that the vocabulary does not know is a warning.
  describe "a well-formed unknown code" do
    it "only warns" do
      query = cdb.query(%w[icd9 412 000.00])
      _(query.validation_errors).must_equal([])
      _(by_operator(query.warnings)).must_equal({ "icd9" => [ [ "unknown code(s)", "000.00" ] ] })
    end

    it "still warns next to a malformed code" do
      query = cdb.query(%w[icd9 410* 000.00])
      _(query.errors).must_equal([])
      _(by_operator(query.warnings)).must_equal(
        { "icd9" => [ [ "improperly formatted code", "410*" ], [ "unknown code(s)", "000.00" ] ] }
      )
    end
  end

  # Ryan ruled 2026-10-30 (seeds conceptql-0eb and conceptql-ysx): a code that
  # does not match its vocabulary's format is a warning, and the statement
  # stays valid. The malformed code matches no rows. There is no prefix
  # matching, so 410* does not select 410.00.
  describe "a malformed code" do
    it "warns and leaves the statement valid" do
      query = cdb.query(%w[icd9 410*])
      _(query.validation_errors).must_equal([])
      counted = ConceptQL::Annotation.new(query.annotate)
      _(by_operator(counted.warnings)).must_equal({ "icd9" => [ [ "improperly formatted code", "410*" ] ] })
      _(counted.each_operator.to_h { |op| [ op.name, op.annotation["counts"] ] })
        .must_equal({ "icd9" => { "condition_occurrence" => { "rows" => 0, "n" => 0 } } })
    end

    it "does not stop annotate from counting the operator's other codes" do
      annotation = cdb.query(%w[icd9 412 410*]).annotate.last[:annotation]
      _(annotation[:errors]).must_be_nil
      _(annotation[:warnings]).must_equal([ [ "improperly formatted code", "410*" ] ])
      _(annotation[:counts]).must_equal(cdb.query(%w[icd9 412]).annotate.last[:annotation][:counts])
      _(annotation[:counts][:condition_occurrence][:rows]).must_be :>, 0
    end
  end

  describe "when tables aren't available" do
    # Before conceptql-brm a real database whose search path held no
    # vocabulary annotated as if no code existed and gave no warning. Seed
    # conceptql-ysx ruled (option A) that its Database raises instead.
    it "raises NoVocabularyError on a real database without vocabulary" do
      seq_db = Sequel.connect(DB.opts.except(:after_connect).merge(search_path: "bad_path"))
      _ { ConceptQL::Database.new(seq_db) }.must_raise ConceptQL::Lexicon::NoVocabularyError
    ensure
      seq_db&.disconnect
    end

    # Before conceptql-brm this test used the real database with the search
    # path "bad_path", which now raises. A database-less Database still has
    # no vocabulary and still reports the formats.
    it "should still report if codes aren't properly formatted" do
      db = ConceptQL::Database.new(nil)
      query = db.query([ "union", %w[cpt 0000], [ "icd9", "00.00" ] ])
      annotation = ConceptQL::Annotation.new(query.annotate(skip_counts: true))
      _(annotation.errors).must_equal([])
      _(by_operator(annotation.warnings)).must_equal(
        { "cpt" => [ [ "improperly formatted code", "0000" ] ],
          "icd9" => [ [ "improperly formatted code", "00.00" ] ] }
      )
      _(annotation.each_operator.to_h { |op| [ op.name, op.annotation["counts"] ] }).must_equal(
        { "cpt" => { "procedure_occurrence" => { "rows" => 0, "n" => 0 } },
          "icd9" => { "condition_occurrence" => { "rows" => 0, "n" => 0 } },
          "union" => { "procedure_occurrence" => { "rows" => 0, "n" => 0 },
                       "condition_occurrence" => { "rows" => 0, "n" => 0 } } }
      )
    end
  end
end

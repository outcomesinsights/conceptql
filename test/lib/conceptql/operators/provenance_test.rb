# frozen_string_literal: true

require_relative "../../../db_helper"

# provenance keeps records by their file provenance (file_provenance_type)
# and their code provenance (code_provenance_type). In the test data, ICD-9
# 250.00 has inpatient, outpatient and carrier claim records. Its code
# provenance is unspecified, except for a few inpatient records with primary
# codes and a few outpatient records with admitting codes.
describe ConceptQL::Operators::Provenance do
  def statement(*keywords)
    [ "provenance", %w[icd9 250.00], *keywords ]
  end

  def records(*keywords)
    CDB.query(statement(*keywords)).query.select_map(%i[criterion_table criterion_id]).sort
  end

  def errors(*keywords)
    CDB.query(statement(*keywords)).annotate.last[:annotation][:errors]
  end

  describe "with a plain keyword" do
    it "keeps the records whose file provenance is in the file keyword's concepts" do
      inpatient = records("inpatient")

      _(inpatient).wont_be_empty
      _(inpatient.size).must_be :<, records("claim").size
    end

    it "keeps the records whose code provenance is in the code keyword's concepts" do
      primary = records("primary_or_first")

      _(primary).wont_be_empty
      _(primary.size).must_be :<, records("inpatient").size
    end

    it "checks both columns for each keyword" do
      sql = CDB.query(statement("inpatient")).sql

      _(sql).must_match(/["`]file_provenance_type["`] IN .* OR .*["`]code_provenance_type["`] IN/m)
    end

    it "keeps the records of any of several keywords" do
      _(records("inpatient", "outpatient")).must_equal (records("inpatient") + records("outpatient")).uniq.sort
    end

    it "reports a keyword that names no provenance concept" do
      _(errors("inpatient", "garbage")).must_equal [ [ "unrecognized keywords", "garbage" ] ]
    end
  end

  # "*" asks for any provenance. It builds the condition that provenance
  # with no keyword built before 2026-10-31: either column is in the
  # descendants of any provenance concept.
  describe "with the keyword \"*\"" do
    # Every ICD-9 250.00 record comes from a claim file.
    it "keeps every record with a provenance" do
      _(records("*")).must_equal records("claim")
    end

    it "is valid" do
      _(errors("*")).must_be_nil
    end

    it "checks both columns" do
      _(CDB.query(statement("*")).sql)
        .must_match(/["`]file_provenance_type["`] IN .* OR .*["`]code_provenance_type["`] IN/m)
    end

    # Keywords are ORed, so "*" with any other keyword is "*".
    it "keeps the same records with other keywords" do
      _(records("inpatient", "*", "outpatient:unspecified")).must_equal records("*")
    end

    it "is valid with other keywords" do
      _(errors("*", "inpatient", "outpatient:unspecified")).must_be_nil
    end

    it "still reports an unrecognized keyword beside it" do
      _(errors("*", "garbage")).must_equal [ [ "unrecognized keywords", "garbage" ] ]
    end
  end

  describe "with no keyword" do
    let(:no_keywords) { [ "no provenance keywords; use \"*\" for any provenance" ] }

    it "reports that it has no keywords" do
      _(errors).must_equal [ no_keywords ]
    end

    it "is refused in the plain query" do
      error = _ { CDB.query(statement).sql }.must_raise ConceptQL::InvalidStatementError
      _(by_operator(error.errors).values).must_equal [ [ no_keywords ] ]
    end

    it "reports that it has no keywords without a database" do
      cdb = ConceptQL::Database.new(nil, data_model: :gdm)
      annotated = cdb.query(statement).annotate(skip_counts: true)

      _(annotated.last[:annotation][:errors]).must_equal [ no_keywords ]
    end
  end

  describe "with a file:code keyword" do
    it "keeps the records with the file provenance AND the code provenance" do
      pair = records("inpatient:unspecified")

      _(pair).wont_be_empty
      _(pair).must_equal records("inpatient") & records("unspecified")
      _(pair.size).must_be :<, records("inpatient").size
      _(pair.size).must_be :<, records("unspecified").size
    end

    it "keeps nothing when no record has both provenances" do
      _(records("outpatient")).wont_be_empty
      _(records("primary_or_first")).wont_be_empty
      _(records("outpatient:primary_or_first")).must_be_empty
    end

    it "keeps the records of any of several keywords" do
      _(records("inpatient:primary_or_first", "outpatient:unspecified"))
        .must_equal (records("inpatient:primary_or_first") + records("outpatient:unspecified")).sort
    end

    it "keeps the records of a pair or a plain keyword" do
      _(records("inpatient:primary_or_first", "carrier_claim"))
        .must_equal (records("inpatient:primary_or_first") + records("carrier_claim")).sort
    end

    it "is valid" do
      _(errors("inpatient:primary_or_first", "outpatient:unspecified", "carrier_claim")).must_be_nil
    end

    # With no lexicon there are no provenance concepts, so nothing is checked.
    it "annotates without a database" do
      cdb = ConceptQL::Database.new(nil, data_model: :gdm)
      annotated = cdb.query(statement("inpatient:primary_or_first")).annotate(skip_counts: true)

      _(annotated.last[:annotation][:errors]).must_be_nil
      _(annotated.last[:annotation][:counts].keys).must_equal [ :condition_occurrence ]
    end
  end

  describe "with a malformed or unknown file:code keyword" do
    [
      "inpatient:primary:first",
      ":primary",
      "inpatient:",
      ":",
      "primary:inpatient",
      "garbage:primary",
      "inpatient:garbage",
      "inpatient:outpatient",
      "primary:first",
      "*:primary_or_first",
      "inpatient:*",
      "*:*"
    ].each do |keyword|
      it "reports #{keyword.inspect} as written" do
        _(errors(keyword)).must_equal [ [ "unrecognized keywords", keyword ] ]
      end

      it "refuses #{keyword.inspect} in the plain query" do
        error = _ { CDB.query(statement(keyword)).sql }.must_raise ConceptQL::InvalidStatementError
        _(by_operator(error.errors).values).must_equal [ [ [ "unrecognized keywords", keyword ] ] ]
      end
    end

    it "reports only the bad keywords, in the order written" do
      _(errors("inpatient:garbage", "inpatient:primary", "garbage", "outpatient"))
        .must_equal [ [ "unrecognized keywords", "inpatient:garbage", "garbage" ] ]
    end
  end

  # Provenance keywords have no vocabulary_formats row, so they match their
  # concept codes exactly (seed conceptql-oji ruling "b"). Every provenance
  # concept code is in lower case. This reverses bead conceptql-sxqe, which
  # made the validation ignore case.
  describe "with a keyword in another case" do
    [
      "Inpatient",
      "PRIMARY_OR_FIRST",
      "CARRIER_CLAIM",
      "INPATIENT:Primary_Or_First",
      "Outpatient:UNSPECIFIED",
      "inpatient:Primary_Or_First",
      "GARBAGE",
      "Garbage:Primary",
      "INPATIENT:Garbage",
      "PRIMARY:INPATIENT",
      "Inpatient:Outpatient",
      "INPATIENT:PRIMARY:FIRST"
    ].each do |keyword|
      it "reports #{keyword.inspect} as written" do
        _(errors(keyword)).must_equal [ [ "unrecognized keywords", keyword ] ]
      end

      it "refuses #{keyword.inspect} in the plain query" do
        error = _ { CDB.query(statement(keyword)).sql }.must_raise ConceptQL::InvalidStatementError
        _(by_operator(error.errors).values).must_equal [ [ [ "unrecognized keywords", keyword ] ] ]
      end
    end

    it "reports each keyword in another case beside the same keyword in lower case" do
      _(errors("inpatient", "Inpatient", "inpatient:primary_or_first", "INPATIENT:PRIMARY_OR_FIRST"))
        .must_equal [ [ "unrecognized keywords", "Inpatient", "INPATIENT:PRIMARY_OR_FIRST" ] ]
    end

    it "reports each spelling of an unknown keyword, in the order written" do
      _(errors("Garbage", "Inpatient", "garbage", "INPATIENT:GARBAGE"))
        .must_equal [ [ "unrecognized keywords", "Garbage", "Inpatient", "garbage", "INPATIENT:GARBAGE" ] ]
    end
  end
end

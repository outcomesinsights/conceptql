# frozen_string_literal: true

require_relative "../../../db_helper"

# A program that looks up a code in another case than the stored one gets
# ConceptQL::CodeCaseMismatchError (bead conceptql-rz8s). A statement does
# not: it keeps its warning or its validation error, selects nothing, and
# still lists its codes. These run against the test data, in every config.
describe "a code in another case than the stored code" do
  def annotation(statement)
    CDB.query(statement).scope_annotate(skip_counts: true)
  end

  def warnings(statement)
    annotation(statement)[:warnings].fetch(statement.first, [])
  end

  def count(statement)
    CDB.query(statement).query.count
  end

  describe "in a program's lookup" do
    let(:dm) { CDB.data_model }

    # The premise: the test data stores the code in upper case.
    it "raises from concept_ids for GDM_PROV line, and names LINE" do
      _(dm.concept_codes(DB, "GDM_PROV")).must_include "LINE"

      error = _ { dm.concept_ids(DB, "GDM_PROV", %w[line]) }.must_raise ConceptQL::CodeCaseMismatchError
      _(error.message).must_include '"LINE"'
      _(error.message).must_include "GDM_PROV"
    end

    it "returns the concept of LINE" do
      _(dm.concept_ids(DB, "GDM_PROV", %w[LINE]).size).must_equal 1
    end

    it "returns nothing for a code that matches nothing in any case" do
      _(dm.concept_ids(DB, "GDM_PROV", %w[no_such_code])).must_equal []
    end
  end

  describe "in a statement" do
    # icd10cm has a format row, so i16.5 gets the format warning.
    it "warns about the format of i16.5, selects nothing and lists the code" do
      statement = %w[icd10cm i16.5]

      _(warnings(statement)).must_include [ ConceptQL::Operators::Operator::BAD_FORMAT, "i16.5" ]
      _(count(statement)).must_equal 0
      _(CDB.query(statement).code_list.map { |code| [ code.code, code.description ] }).must_equal [ [ "i16.5", nil ] ]
    end

    # cms_type_of_service has no format row, so "a" passes the format check
    # and reaches the unknown-code check, the reused-code check and the code
    # list. The vocabulary stores "A".
    it "reports a of cms_type_of_service as unknown, selects nothing and lists the code" do
      _(CDB.data_model.concept_codes(DB, "CMS_TYPE_OF_SERVICE")).must_include "A"
      statement = %w[cms_type_of_service a]

      _(warnings(statement)).must_include [ ConceptQL::Operators::Operator::UNKNOWN_CODE, "a" ]
      _(count(statement)).must_equal 0
      _(CDB.query(statement).code_list.map { |code| [ code.code, code.description ] }).must_equal [ [ "a", nil ] ]
    end

    # The CMS Place of Service vocabulary stores OMOP4822036. Query refuses
    # the SQL of an invalid statement, so this builds the operator directly.
    it "reports omop4822036 as an unknown place of service and builds its condition" do
      _(CDB.data_model.concept_codes(DB, "CMS Place of Service")).must_include "OMOP4822036"
      query = CDB.query([ "place_of_service_filter", %w[icd9 412], "omop4822036" ])

      _(query.annotate.last[:annotation][:errors]).must_equal [ [ ConceptQL::Operators::Operator::UNKNOWN_CODE, "omop4822036" ] ]
      _(query.operator.evaluate(DB).sql).must_match(/visit_source_concept_id/)
    end

    # Provenance keywords are concept codes in lower case. Query refuses the
    # SQL of an invalid statement, but the operator still builds its
    # condition (Provenanceable#pair_condition), so this builds it directly.
    it "reports Inpatient as a bad provenance keyword and builds its condition" do
      %w[Inpatient inpatient:Primary].each do |keyword|
        query = CDB.query([ "provenance", %w[icd9 250.00], keyword ])

        _(query.annotate.last[:annotation][:errors]).must_equal [ [ "unrecognized keywords", keyword ] ]
        _(query.operator.evaluate(DB).sql).must_match(/file_provenance_type/)
      end
    end
  end
end

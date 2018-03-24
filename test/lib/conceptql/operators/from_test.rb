require_relative "../../../db_helper"

describe ConceptQL::Operators::From do
  it "should have correct, NULL columns when used with supplemented statements, and provided with query_cols option" do
    DB.create_table!(:test_from_table, as: CDB.query(["icd9", "412"]).query, temp: true)

    stmt = [:after, {
      left: [:ndc, "012345678"],
      right: [:from, :test_from_table, query_cols: ConceptQL::Scope::DEFAULT_COLUMNS.keys]
    }]

    CDB.query(stmt).annotate.must_equal(["after", {:left=>["ndc", "012345678", {:annotation=>{:counts=>{:drug_exposure=>{:rows=>0, :n=>0}}, :warnings=>[["unknown source code", "012345678"], ["unknown source code", "012345678"]]}, :name=>"NDC"}], :right=>["from", :test_from_table, {:query_cols=>[:person_id, :criterion_id, :criterion_table, :criterion_domain, :start_date, :end_date, :source_value, :source_vocabulary_id], :annotation=>{:counts=>{:condition_occurrence=>{:rows=>48, :n=>37}, :invalid=>{:rows=>0, :n=>0}}}, :name=>"From"}], :annotation=>{:counts=>{:drug_exposure=>{:rows=>0, :n=>0}}}, :name=>"After"}])
  end

  it "should have correct, NULL columns when used with supplemented statements" do
    DB.create_table!(:test_from_table, as: CDB.query(["icd9", "412"]).query, temp: true)

    stmt = [:after, {
      left: [:ndc, "012345678"],
      right: [:from, :test_from_table, query_cols: ConceptQL::Scope::DEFAULT_COLUMNS.keys]
    }]

    CDB.query(stmt).annotate.must_equal(["after", {:left=>["ndc", "012345678", {:annotation=>{:counts=>{:drug_exposure=>{:rows=>0, :n=>0}}, :warnings=>[["unknown source code", "012345678"], ["unknown source code", "012345678"]]}, :name=>"NDC"}], :right=>["from", :test_from_table, {:query_cols=>[:person_id, :criterion_id, :criterion_table, :criterion_domain, :start_date, :end_date, :source_value, :source_vocabulary_id], :annotation=>{:counts=>{:condition_occurrence=>{:rows=>48, :n=>37}, :invalid=>{:rows=>0, :n=>0}}}, :name=>"From"}], :annotation=>{:counts=>{:drug_exposure=>{:rows=>0, :n=>0}}}, :name=>"After"}])
  end

  it "should handle QualifiedIdentifiers" do
    DB.create_table!(:test_from_table, as: CDB.query(["icd9", "412"]).query, temp: true)

    qi = Sequel.qualify(:test_from_schema, :test_from_table)
    stmt = [:after, {
      left: [:ndc, "012345678"],
      right: [:from, qi, query_cols: ConceptQL::Scope::DEFAULT_COLUMNS.keys]
    }]

    sql = CDB.query(stmt).sql
    sql.must_match(/test_from_schema/)
    sql.must_match(/test_from_table/)
  end
end



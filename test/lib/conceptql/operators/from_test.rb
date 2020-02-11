require_relative "../../../db_helper"

describe ConceptQL::Operators::From do
  test_table_statement = [
    :window,
    [:icd9, "412", uuid: true],
    window_table: [:date_range, {
      start: "2001-01-01",
      end: "2020-12-31"
    }]
  ]

  @test_table ||= DB.create_table!(:test_from_table, as: CDB.query(test_table_statement).query, temp: true)
  it "should handle QualifiedIdentifiers" do
    qi = Sequel.qualify(:test_from_schema, :test_from_table)
    stmt = [:after, {
      left: [:ndc, "012345678"],
      right: [:from, qi, query_cols: DB[:test_from_table].columns]
    }]

    sql = CDB.query(stmt).sql
    _(sql).must_match(/test_from_schema/)
    _(sql).must_match(/test_from_table/)
  end

  it "should handle window_id column" do
    CDB.query([:first, [:from, :test_from_table, query_cols: DB[:test_from_table].columns]]).all.length
  end
end

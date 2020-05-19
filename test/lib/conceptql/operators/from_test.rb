require_relative "../../../db_helper"

describe ConceptQL::Operators::From do
  describe "with test table from a statement" do
    before do
      DB.create_table!(:test_from_table, as: CDB.query(table_test_statement).query, temp: true)
    end

    let(:table_test_statement) do 
      [
        :window,
        [:icd9, "412", uuid: true],
        window_table: [:date_range, {
          start: "2001-01-01",
          end: "2020-12-31"
        }]
      ]
    end

    it "should handle QualifiedIdentifiers" do
      qi = Sequel[:test_from_table]
      stmt = [:after, {
        left: [:ndc, "012345678"],
        right: [:from, qi, query_cols: DB[:test_from_table].columns]
      }]

      sql = CDB.query(stmt).sql
      _(sql).must_match(/test_from_table/)
    end

    it "should handle window_id column" do
      CDB.query([:first, [:from, :test_from_table, query_cols: DB[:test_from_table].columns]]).all.length
    end
  end

  describe "with test table missing many columns" do
    before do
      DB.create_table!(:test_from_table, as: DB.select(Sequel["a"].cast(String).as(:uuid), Sequel[1].as(:person_id)), temp: true)
    end

    let(:stmt) do 
      [
        :match, {
          left: [:icd9, "412", uuid: true],
          right: [ :from, Sequel[:test_from_table] ],
          only_columns: [:uuid]
        }
      ]
    end

    it "should handle QualifiedIdentifiers" do
      sql = CDB.query(stmt).sql
      _(sql).must_match(/test_from_table/)
      _(sql).must_match(/CAST\(NULL AS Date\) AS "start_date"/)
    end
  end
end

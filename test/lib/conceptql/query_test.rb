require_relative '../../db_helper'

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    _(query(
      [:foo]
    ).annotate).must_equal(
      ["foo", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["invalid operator", "foo"]]}, :name=>"Invalid"}]
    )
  end

  it "should handle query_cols for non-CDM tables" do
    _(query(
      [:from, "other_table"]
    ).query_cols).must_equal(ConceptQL::Scope::DEFAULT_COLUMNS.keys)
  end

  it "should raise error if attempting to execute invalid recall" do
    _(proc do
      criteria_ids(
      ["after",
        {:left=>["during",
                 {:left=>["occurrence", 4, ["icd9", "203.0x", {"label"=>"Meyloma Dx"}]],
                  :right=>["time_window", ["first", ["recall", "Meyloma Dx"]], {"start"=>"0", "end"=>"90d"}]}],
         :right=>["union",
                  ["during",
                   {:left=>["time_window", ["recall", "Qualifying Meyloma Dx"], {"start"=>"-90d", "end"=>"0", "label"=>"Meyloma 90-day Lookback"}],
                    :right=>["cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275", "88291", "88305", {"label"=>"Bone Marrow"}]}],
                  ["occurrence", 2, ["during",
                                     {:left=>["cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", {"label"=>"Other Tests"}],
                                      :right=>["recall", "Meyloma 90-day Lookback"]}]]]}]
      )
    end).must_raise
  end

  describe "#code_list" do
    it "should handle nil for a DB" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["union",["cpt","80230"],["icd9", "250.00", "250.02"]])
      expected = [
        "CPT 80230",
        "ICD-9 CM 250.00",
        "ICD-9 CM 250.02"
      ]
      _(query.code_list.map(&:to_s)).must_equal(expected)
    end

    it "should handle nil for preferred name" do
      db = ConceptQL::Database.new(DB)
      query = db.query(["revenue_code", "0100"])
      _(query.code_list.map(&:to_s)).must_equal([
        "Revenue Code 0100: All-Inclusive Room and Board Plus Ancillary"
      ])
    end

    it "should return codes even if database search_path is bad" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","80230"],["icd9", "250.00", "250.02"]])
      expected = [
        "CPT 80230",
        "ICD-9 CM 250.00",
        "ICD-9 CM 250.02"
      ]
      _(query.code_list.map(&:to_s)).must_equal(expected)
    end

    it "should return asterisk when selecting all" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","*"],["icd9", "250.00", "*"]])
      _(query.code_list(seq_db).map(&:to_s)).must_equal([
        "CPT *: ALL CODES",
        "ICD-9 CM *: ALL CODES"
      ])
    end

    it "should return codes from vocabulary-based operators even with no db" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["union", ["cpt_or_hcpcs","80230"], ["ATC", "*"]])
      _(query.code_list(nil).map(&:to_s)).must_equal([
        "CPT or HCPCS 80230",
				"WHO ATC *: ALL CODES"
      ])
    end

    it "should return codes even if the code doesn't exist in the database" do
      query = CDB.query(["hcpcs", "A0000", "A0021"])
      _(query.code_list.map(&:code).sort).must_equal(["A0000", "A0021"])
    end
  end
end


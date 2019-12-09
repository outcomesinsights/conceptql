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

  describe "#sql(:formatted)" do
    let :cdb do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus, force_temp_tables: false)
    end

    it "should produce formatted SQL" do
      _(cdb.query([:icd9, "412"]).sql(:formatted)).must_match("          ")
    end

    it "should timeout after 10 seconds if can't parse" do
      _(cdb.query(json_fixture(:sqlformat_killer)).sql(:formatted)).wont_match(/  /)
    end

    describe "with temp tables" do
      let :cdb do
        ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus, force_temp_tables: true, scratch_database: "scratch")
      end

      it "should use CREATE TABLE statements" do
        _(cdb.query([:icd9, "412", label: "l"]).sql(:formatted, :create_tables)).must_match(/CREATE TABLE/)
      end
    end

    describe "without temp tables" do
      let :cdb do
        ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus, force_temp_tables: false)
      end

      it "should use WITH statements" do
        if ENV["CONCEPTQL_AVOID_CTES"] == "true"
          skip
        else
          _(cdb.query([:icd9, "412", label: "l"]).sql(:formatted)).must_match(/WITH/)
        end
      end
    end
  end

  describe "#code_list" do
    it "should handle nil for a DB" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
      expected = if ENV["LEXICON_URL"]
        [
          "CPT 99214: Office or other outpatient visit for the evaluation and management of an established patient, which requires at least 2 of these 3 key components: A detailed history; A detailed examination; Medical decision making of moderate complexity. Counseling and/o",
          "ICD-9 CM 250.00: Diabetes mellitus without mention of complication, type II or unspecified type, not stated as uncontrolled",
          "ICD-9 CM 250.02: Diabetes mellitus without mention of complication, type II or unspecified type, uncontrolled"
        ]
      else
        [
          "CPT 99214",
          "ICD-9 CM 250.00",
          "ICD-9 CM 250.02"
        ]
      end
      _(query.code_list.map(&:to_s)).must_equal(expected)
    end

    it "should handle nil for preferred name" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["revenue_code", "0100"])
      _(query.code_list.map(&:to_s)).must_equal([
        "Revenue Code 0100: All-Inclusive Room and Board Plus Ancillary"
      ])
    end

    it "should return codes even if database search_path is bad" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
      expected = if ENV["LEXICON_URL"]
        [
          "CPT 99214: Office or other outpatient visit for the evaluation and management of an established patient, which requires at least 2 of these 3 key components: A detailed history; A detailed examination; Medical decision making of moderate complexity. Counseling and/o",
          "ICD-9 CM 250.00: Diabetes mellitus without mention of complication, type II or unspecified type, not stated as uncontrolled",
          "ICD-9 CM 250.02: Diabetes mellitus without mention of complication, type II or unspecified type, uncontrolled"
        ]
      else
        [
          "CPT 99214",
          "ICD-9 CM 250.00",
          "ICD-9 CM 250.02"
        ]
      end
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
      query = db.query(["union", ["cpt_or_hcpcs","99214"], ["ATC", "*"]])
      _(query.code_list(nil).map(&:to_s)).must_equal([
				"CPT or HCPCS 99214: Office or other outpatient visit for the evaluation and management of an established patient, which requires at least 2 of these 3 key components: A detailed history; A detailed examination; Medical decision making of moderate complexity. Counseling and/o",
				"WHO ATC *: ALL CODES"
      ])
    end

    it "should return codes even if the code doesn't exist in the database" do
      query = CDB.query(["hcpcs", "A0000", "A0021"])
      _(query.code_list.map(&:code)).must_equal(["A0000", "A0021"])
    end
  end
end


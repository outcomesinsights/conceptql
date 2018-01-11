require_relative '../../db_helper'

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    query(
      [:foo]
    ).annotate.must_equal(
      [:foo, {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["invalid operator", :foo]]}, :name=>"Invalid"}]
    )
  end

  it "should handle query_cols for non-CDM tables" do
    query(
      [:from, "other_table"]
    ).query_cols.must_equal(ConceptQL::Scope::DEFAULT_COLUMNS.keys)
  end

  it "should raise error if attempting to execute invalid recall" do
    proc do
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
    end.must_raise
  end

  describe "#formatted_sql" do
    let :cdb do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    end

    it "should produce formatted SQL" do
      expected = "SELECT *
FROM
  (SELECT *
   FROM
     (SELECT \"person_id\" AS \"person_id\",
             \"condition_occurrence_id\" AS \"criterion_id\",
             cast('condition_occurrence' AS text) AS \"criterion_table\",
             cast('condition_occurrence' AS text) AS \"criterion_domain\",
             cast(\"condition_start_date\" AS date) AS \"start_date\",
             cast(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\",
             cast(\"condition_source_value\" AS text) AS \"source_value\"
      FROM \"condition_occurrence\" AS \"tab\"
      WHERE ((\"condition_source_value\" IN ('412'))
             AND (\"condition_source_vocabulary_id\" = 2))) AS \"t1\") AS \"t1\""

      cdb.query([:icd9, "412"]).formatted_sql.must_equal(expected)
    end

    it "should timeout after 10 seconds if can't parse" do
      cdb.query(json_fixture(:sqlformat_killer)).formatted_sql.wont_match(/  /)
    end

    describe "with temp tables" do
      let :cdb do
        ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus, force_temp_tables: true, scratch_database: "scratch")
      end

      it "should use CREATE TABLE statements" do
        cdb.query([:icd9, "412", label: "l"]).formatted_sql.must_match(/CREATE TABLE/)
      end
    end

    describe "without temp tables" do
      let :cdb do
        ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus, force_temp_tables: false)
      end

      it "should use WITH statements" do
        cdb.query([:icd9, "412", label: "l"]).formatted_sql.must_match(/WITH/)
      end
    end
  end

  describe "#code_list" do
    it "should list codes and descriptions" do
      db = ConceptQL::Database.new(DB)
      query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
      query.code_list(DB).map(&:to_s).must_equal([
        "CPT 99214: Office or other outpatient visit for the evaluation and management of an established patient, which requires at least 2 of these 3 key components: A detailed history; A detailed examination; Medical decision making of moderate complexity. Counseling and/o",
        "ICD-9 CM 250.00: Diabetes mellitus without mention of complication, type II or unspecified type, not stated as uncontrolled",
        "ICD-9 CM 250.02: Diabetes mellitus without mention of complication, type II or unspecified type, uncontrolled"
      ])
    end

    it "should handle nil for a DB" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
      query.code_list.map(&:to_s).must_equal([
        "CPT 99214",
        "ICD-9 CM 250.00",
        "ICD-9 CM 250.02"
      ])
    end

    it "should handle nil for preferred name" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["revenue_code", "0100"])
      query.code_list.map(&:to_s).must_equal([
        "Revenue Code 0100"
      ])
    end

    it "should return codes even if database search_path is bad" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
      query.code_list(seq_db).map(&:to_s).must_equal([
        "CPT 99214",
        "ICD-9 CM 250.00",
        "ICD-9 CM 250.02"
      ])
    end

    it "should return asterisk when selecting all" do
      seq_db = Sequel.connect(DB.opts.merge(search_path: 'bad_path'))
      db = ConceptQL::Database.new(seq_db)
      query = db.query(["union",["cpt","*"],["icd9", "250.00", "*"]])
      query.code_list(seq_db).map(&:to_s).must_equal([
        "CPT *: ALL CODES",
        "ICD-9 CM *: ALL CODES"
      ])
    end

    it "should return codes from vocabulary-based operators" do
      db = ConceptQL::Database.new(DB)
      query = db.query(["union", ["cpt_or_hcpcs","99214"], ["ATC", "*"]])
      query.code_list(DB).map(&:to_s).must_equal([
        "CPT or HCPCS 99214: Level 4 outpatient visit for evaluation and management of established patient with problem of moderate to high severity, including detailed history and medical decision making of moderate complexity - typical time with patient and/or family 25 minutes", "WHO ATC *: ALL CODES"
      ])
    end

    it "should return codes from vocabulary-based operators even with no db" do
      db = ConceptQL::Database.new(nil)
      query = db.query(["union", ["cpt_or_hcpcs","99214"], ["ATC", "*"]])
      query.code_list(nil).map(&:to_s).must_equal([
        "CPT or HCPCS 99214", "WHO ATC *: ALL CODES"
      ])
    end
  end
end


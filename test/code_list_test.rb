require_relative 'db_helper'
require_relative 'db'
require_relative '../lib/conceptql/query'
require_relative '../lib/conceptql/database'

describe ConceptQL::Operators do
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
    db = ConceptQL::Database.new(DB)
    query = db.query(["union",["cpt","99214"],["icd9", "250.00", "250.02"]])
    query.code_list(nil).map(&:to_s).must_equal([
      "CPT 99214",
      "ICD-9 CM 250.00",
      "ICD-9 CM 250.02"
    ])
  end

  it "should handle nil for preferred name" do
    db = ConceptQL::Database.new(DB)
    query = db.query(["revenue_code", "0100"])
    query.code_list(nil).map(&:to_s).must_equal([
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

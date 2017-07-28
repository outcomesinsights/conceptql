require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file" do
    ConceptQL::Operators.operators[:gdm]["ADMSRCE"].must_equal ConceptQL::Operators::Vocabulary
  end

  it "should produce correct SQL under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["ADMSRCE", "12"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL under gdm for older selection operators" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["icd9", "412"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL for select all under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["ATC", "*"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('drug_exposure' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE (\"vocabulary_id\" = 'ATC')))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL for select all under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["ATC", "*"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"drug_exposure_id\" AS \"criterion_id\", CAST('drug_exposure' AS text) AS \"criterion_table\", CAST('drug_exposure' AS text) AS \"criterion_domain\", CAST(\"drug_exposure_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"drug_exposure_end_date\", \"drug_exposure_start_date\") AS date) AS \"end_date\", CAST(\"drug_source_value\" AS text) AS \"source_value\" FROM \"drug_exposure\" WHERE (\"drug_source_vocabulary_id\" = 21)) AS \"t1\") AS \"t1\""
  end
end

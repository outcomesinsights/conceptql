require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::MultipleVocabularies do
  it "should appear for both GDM" do
    ConceptQL::Operators.operators[:gdm]["icd_10_conditions"].must_equal ConceptQL::Operators::MultipleVocabularies
    ConceptQL::Operators.operators[:gdm]["cpt_or_hcpcs"].must_equal ConceptQL::Operators::MultipleVocabularies
  end

  it "should appear for both OMOPv4+" do
    ConceptQL::Operators.operators[:omopv4_plus]["icd_10_conditions"].must_equal ConceptQL::Operators::MultipleVocabularies
    ConceptQL::Operators.operators[:omopv4_plus]["cpt_or_hcpcs"].must_equal ConceptQL::Operators::MultipleVocabularies
  end

  it "should produce correct SQL under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["icd_10_conditions", "I10"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\", \"criterion_id\", \"criterion_table\", \"criterion_domain\", \"start_date\", \"end_date\", \"source_value\" FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD10') AND (\"concept_code\" IN ('I10')))))) AS \"t1\" UNION (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD10CM') AND (\"concept_code\" IN ('I10')))))) AS \"t1\")) AS \"t1\") AS \"t1\") AS \"t1\""
    db.query(["cpt_or_hcpcs", "99214"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\", \"criterion_id\", \"criterion_table\", \"criterion_domain\", \"start_date\", \"end_date\", \"source_value\" FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'CPT4') AND (\"concept_code\" IN ('99214')))))) AS \"t1\" UNION (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'HCPCS') AND (\"concept_code\" IN ('99214')))))) AS \"t1\")) AS \"t1\") AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["icd_10_conditions", "I10"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\", \"criterion_id\", \"criterion_table\", \"criterion_domain\", \"start_date\", \"end_date\", \"source_value\" FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"condition_occurrence_id\" AS \"criterion_id\", CAST('condition_occurrence' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", CAST(\"condition_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\", CAST(\"condition_source_value\" AS text) AS \"source_value\" FROM \"condition_occurrence\" WHERE ((\"condition_source_vocabulary_id\" = 34) AND (\"condition_source_value\" IN ('I10')))) AS \"t1\" UNION (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"condition_occurrence_id\" AS \"criterion_id\", CAST('condition_occurrence' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", CAST(\"condition_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\", CAST(\"condition_source_value\" AS text) AS \"source_value\" FROM \"condition_occurrence\" WHERE ((\"condition_source_vocabulary_id\" = 70) AND (\"condition_source_value\" IN ('I10')))) AS \"t1\")) AS \"t1\") AS \"t1\") AS \"t1\""
    db.query(["cpt_or_hcpcs", "99214"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\", \"criterion_id\", \"criterion_table\", \"criterion_domain\", \"start_date\", \"end_date\", \"source_value\" FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"procedure_occurrence_id\" AS \"criterion_id\", CAST('procedure_occurrence' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", CAST(\"procedure_date\" AS date) AS \"start_date\", CAST(coalesce(\"procedure_date\", \"procedure_date\") AS date) AS \"end_date\", CAST(\"procedure_source_value\" AS text) AS \"source_value\" FROM \"procedure_occurrence\" WHERE ((\"procedure_source_vocabulary_id\" = 4) AND (\"procedure_source_value\" IN ('99214')))) AS \"t1\" UNION (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"procedure_occurrence_id\" AS \"criterion_id\", CAST('procedure_occurrence' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", CAST(\"procedure_date\" AS date) AS \"start_date\", CAST(coalesce(\"procedure_date\", \"procedure_date\") AS date) AS \"end_date\", CAST(\"procedure_source_value\" AS text) AS \"source_value\" FROM \"procedure_occurrence\" WHERE ((\"procedure_source_vocabulary_id\" = 5) AND (\"procedure_source_value\" IN ('99214')))) AS \"t1\")) AS \"t1\") AS \"t1\") AS \"t1\""
  end

  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
      row.first[:operator] == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w(operator vocabulary_id domain)
        csv << %w(test test_id test_domain)
      end
      f.rewind
      ConceptQL.stub(:custom_multiple_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
          row.first[:operator] == "test"
        end)
      end
    end
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |key, row|
      row.first[:operator] == "test"
    end)
  end
end



require_relative "../../../helper"

describe ConceptQL::Operators::Gender do
  it "be present in list of operators" do
    ConceptQL::Operators.operators[:omopv4_plus]["gender"].must_equal ConceptQL::Operators::Gender
  end

  describe "under gdm" do
    let(:db) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    end

    it "should work with male" do
      db.query(["gender", "male"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('patients' AS text) AS \"criterion_table\", CAST('person' AS text) AS \"criterion_domain\", CAST(\"birth_date\" AS date) AS \"start_date\", CAST(coalesce(\"birth_date\", \"birth_date\") AS date) AS \"end_date\", CAST(\"patient_id_source_value\" AS text) AS \"source_value\", CAST(NULL AS text) AS \"source_vocabulary_id\" FROM \"patients\" WHERE (\"gender_concept_id\" IN (8507))) AS \"t1\") AS \"t1\""
    end

    it "should work with female" do
      db.query(["gender", "female"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('patients' AS text) AS \"criterion_table\", CAST('person' AS text) AS \"criterion_domain\", CAST(\"birth_date\" AS date) AS \"start_date\", CAST(coalesce(\"birth_date\", \"birth_date\") AS date) AS \"end_date\", CAST(\"patient_id_source_value\" AS text) AS \"source_value\", CAST(NULL AS text) AS \"source_vocabulary_id\" FROM \"patients\" WHERE (\"gender_concept_id\" IN (8532))) AS \"t1\") AS \"t1\""
    end

    it "should work with unknown" do
      db.query(["gender", "unknown"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('patients' AS text) AS \"criterion_table\", CAST('person' AS text) AS \"criterion_domain\", CAST(\"birth_date\" AS date) AS \"start_date\", CAST(coalesce(\"birth_date\", \"birth_date\") AS date) AS \"end_date\", CAST(\"patient_id_source_value\" AS text) AS \"source_value\", CAST(NULL AS text) AS \"source_vocabulary_id\" FROM \"patients\" WHERE ((\"gender_concept_id\" IS NULL) OR (\"gender_concept_id\" NOT IN (8507, 8532)))) AS \"t1\") AS \"t1\""
    end

    it "should work with all" do
      db.query(["gender", "male", "female", "unknown"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('patients' AS text) AS \"criterion_table\", CAST('person' AS text) AS \"criterion_domain\", CAST(\"birth_date\" AS date) AS \"start_date\", CAST(coalesce(\"birth_date\", \"birth_date\") AS date) AS \"end_date\", CAST(\"patient_id_source_value\" AS text) AS \"source_value\", CAST(NULL AS text) AS \"source_vocabulary_id\" FROM \"patients\" WHERE ((\"gender_concept_id\" IN (8507)) OR (\"gender_concept_id\" IN (8532)) OR (\"gender_concept_id\" IS NULL) OR (\"gender_concept_id\" NOT IN (8507, 8532)))) AS \"t1\") AS \"t1\""
    end
  end
end


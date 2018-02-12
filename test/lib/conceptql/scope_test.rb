require_relative "../../helper"

describe ConceptQL::Scope do
  describe "with date literal windows" do
    let(:opts) do
      { scope_opts: { start_date: "2001-01-01", end_date: "2001-12-31" } }
    end

    it "should limit selection by date range under gdm" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["ADMSRCE", "12"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"t1\" WHERE ((CAST('2001-01-01' AS date) <= \"start_date\") AND (\"end_date\" <= CAST('2001-12-31' AS date)))) AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"condition_occurrence_id\" AS \"criterion_id\", CAST('condition_occurrence' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", CAST(\"condition_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\", CAST(\"condition_source_value\" AS text) AS \"source_value\" FROM \"condition_occurrence\" AS \"tab\" WHERE ((\"condition_source_value\" IN ('412')) AND (\"condition_source_vocabulary_id\" = 2))) AS \"t1\") AS \"t1\" WHERE ((CAST('2001-01-01' AS date) <= \"start_date\") AND (\"end_date\" <= CAST('2001-12-31' AS date)))) AS \"t1\""
    end

    it "should limit selection by date range under gdm with old source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"t1\" WHERE ((CAST('2001-01-01' AS date) <= \"start_date\") AND (\"end_date\" <= CAST('2001-12-31' AS date)))) AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"procedure_occurrence_id\" AS \"criterion_id\", CAST('procedure_occurrence' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", CAST(\"procedure_date\" AS date) AS \"start_date\", CAST(coalesce(\"procedure_date\", \"procedure_date\") AS date) AS \"end_date\", CAST(\"procedure_source_value\" AS text) AS \"source_value\" FROM \"procedure_occurrence\" AS \"tab\" WHERE ((\"procedure_source_value\" IN ('99214')) AND (\"procedure_source_vocabulary_id\" = 4))) AS \"t1\") AS \"t1\" WHERE ((CAST('2001-01-01' AS date) <= \"start_date\") AND (\"end_date\" <= CAST('2001-12-31' AS date)))) AS \"t1\""
    end

    it "should limit selection by date range under gdm with old standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'CPT4') AND (\"concept_code\" IN ('99214')))))) AS \"t1\") AS \"t1\" WHERE ((CAST('2001-01-01' AS date) <= \"start_date\") AND (\"end_date\" <= CAST('2001-12-31' AS date)))) AS \"t1\""
    end
  end

  describe "with windows from another table" do
    let(:opts) do
      { scope_opts: { window_table: :jtemp } }
    end

    it "should limit selection by date range under gdm" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["ADMSRCE", "12"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((\"tw\".\"start_date\" <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= \"tw\".\"end_date\"))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"condition_occurrence_id\" AS \"criterion_id\", CAST('condition_occurrence' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", CAST(\"condition_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\", CAST(\"condition_source_value\" AS text) AS \"source_value\" FROM \"condition_occurrence\" AS \"tab\" WHERE ((\"condition_source_value\" IN ('412')) AND (\"condition_source_vocabulary_id\" = 2))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((\"tw\".\"start_date\" <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= \"tw\".\"end_date\"))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under gdm with old source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((\"tw\".\"start_date\" <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= \"tw\".\"end_date\"))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"procedure_occurrence_id\" AS \"criterion_id\", CAST('procedure_occurrence' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", CAST(\"procedure_date\" AS date) AS \"start_date\", CAST(coalesce(\"procedure_date\", \"procedure_date\") AS date) AS \"end_date\", CAST(\"procedure_source_value\" AS text) AS \"source_value\" FROM \"procedure_occurrence\" AS \"tab\" WHERE ((\"procedure_source_value\" IN ('99214')) AND (\"procedure_source_vocabulary_id\" = 4))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((\"tw\".\"start_date\" <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= \"tw\".\"end_date\"))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under gdm with old standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'CPT4') AND (\"concept_code\" IN ('99214')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((\"tw\".\"start_date\" <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= \"tw\".\"end_date\"))) AS \"t1\") AS \"t1\""
    end
  end

  describe "with windows from another table, along with adjustments" do
    let(:opts) do
      { scope_opts: { window_table: :jtemp, adjust_window_start:  "-30d", adjust_window_end: "1m"} }
    end

    it "should limit selection by date range under gdm" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["ADMSRCE", "12"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((CAST((CAST(\"tw\".\"start_date\" AS timestamp) + CAST('-30 days ' AS interval)) AS date) <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= CAST((CAST(\"tw\".\"end_date\" AS timestamp) + CAST('1 months ' AS interval)) AS date)))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"condition_occurrence_id\" AS \"criterion_id\", CAST('condition_occurrence' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", CAST(\"condition_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"condition_end_date\", \"condition_start_date\") AS date) AS \"end_date\", CAST(\"condition_source_value\" AS text) AS \"source_value\" FROM \"condition_occurrence\" AS \"tab\" WHERE ((\"condition_source_value\" IN ('412')) AND (\"condition_source_vocabulary_id\" = 2))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((CAST((CAST(\"tw\".\"start_date\" AS timestamp) + CAST('-30 days ' AS interval)) AS date) <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= CAST((CAST(\"tw\".\"end_date\" AS timestamp) + CAST('1 months ' AS interval)) AS date)))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under gdm with old source vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["icd9", "412"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((CAST((CAST(\"tw\".\"start_date\" AS timestamp) + CAST('-30 days ' AS interval)) AS date) <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= CAST((CAST(\"tw\".\"end_date\" AS timestamp) + CAST('1 months ' AS interval)) AS date)))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under omopv4_plus for standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"procedure_occurrence_id\" AS \"criterion_id\", CAST('procedure_occurrence' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", CAST(\"procedure_date\" AS date) AS \"start_date\", CAST(coalesce(\"procedure_date\", \"procedure_date\") AS date) AS \"end_date\", CAST(\"procedure_source_value\" AS text) AS \"source_value\" FROM \"procedure_occurrence\" AS \"tab\" WHERE ((\"procedure_source_value\" IN ('99214')) AND (\"procedure_source_vocabulary_id\" = 4))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((CAST((CAST(\"tw\".\"start_date\" AS timestamp) + CAST('-30 days ' AS interval)) AS date) <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= CAST((CAST(\"tw\".\"end_date\" AS timestamp) + CAST('1 months ' AS interval)) AS date)))) AS \"t1\") AS \"t1\""
    end

    it "should limit selection by date range under gdm with old standard vocab operator" do
      db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      db.query(["cpt", "99214"], opts).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"og\".* FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('procedure_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'CPT4') AND (\"concept_code\" IN ('99214')))))) AS \"t1\") AS \"og\" INNER JOIN \"jtemp\" AS \"tw\" ON (\"tw\".\"person_id\" = \"og\".\"person_id\") WHERE ((CAST((CAST(\"tw\".\"start_date\" AS timestamp) + CAST('-30 days ' AS interval)) AS date) <= \"og\".\"start_date\") AND (\"og\".\"end_date\" <= CAST((CAST(\"tw\".\"end_date\" AS timestamp) + CAST('1 months ' AS interval)) AS date)))) AS \"t1\") AS \"t1\""
    end
  end
end

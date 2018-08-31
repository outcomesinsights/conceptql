require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file" do
    ConceptQL::Operators.operators[:gdm]["admsrce"].must_equal ConceptQL::Operators::Vocabulary
  end

  it "should produce correct SQL under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["admsrce", "12"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\", CAST(\"clinical_code_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL under gdm for older selection operators" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["icd9", "412"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\", CAST(\"clinical_code_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL for select all under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    db.query(["atc", "*"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('drug_exposure' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\", CAST(\"clinical_code_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE (\"vocabulary_id\" = 'ATC')))) AS \"t1\") AS \"t1\""
  end

  it "should produce correct SQL for select all under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["atc", "*"]).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT \"person_id\" AS \"person_id\", \"drug_exposure_id\" AS \"criterion_id\", CAST('drug_exposure' AS text) AS \"criterion_table\", CAST('drug_exposure' AS text) AS \"criterion_domain\", CAST(\"drug_exposure_start_date\" AS date) AS \"start_date\", CAST(coalesce(\"drug_exposure_end_date\", \"drug_exposure_start_date\") AS date) AS \"end_date\", CAST(\"drug_source_value\" AS text) AS \"source_value\", CAST(\"drug_source_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"drug_exposure\" WHERE (\"drug_source_vocabulary_id\" = 21)) AS \"t1\") AS \"t1\""
  end

  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
      row[:id] == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w(id omopv4_vocabulary_id vocabulary_full_name vocabulary_short_name domain hidden format_regexp)
        csv << %w(test 0 test_full test_short test_domain) + [nil, nil]
      end
      f.rewind
      ConceptQL.stub(:custom_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
          row[:id] == "test"
        end)
      end
    end
    assert_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
      row[:id] == "test"
    end)
  end

  describe "with example vocabularies" do
    let(:db) { Sequel.connect("sqlite:/") }

    before do
      db.create_table!(:vocabularies) do
        String :omopv4_id
        String :omopv5_id
        String :vocabulary_name
      end
      db[:vocabularies].multi_insert([{ omopv4_id: "10000000", omopv5_id: "EXAMPLE", vocabulary_name: "Example Vocabulary" }])
    end

    it "should read from lexicon" do
      assert_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
        row[:id] == "EXAMPLE"
      end)

      ConceptQL::Database.stub(:lexicon, ConceptQL::Lexicon.new(db)) do
        refute_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
          row[:id] == "EXAMPLE"
        end)
      end

      assert_empty(ConceptQL::Operators::Vocabulary.get_all_vocabs.select do |row|
        row[:id] == "EXAMPLE"
      end)
    end

    it "should use proper case sensitivity for dynamic vocabularies" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      lexicon = ConceptQL::Lexicon.new(db)
      ConceptQL::Operators.stub(:operators, {gdm: {}, omopv4_plus: {}}) do
        ConceptQL::Database.stub(:lexicon, ConceptQL::Lexicon.new(db)) do
          cdb.stub(:lexicon, lexicon) do
            ConceptQL::Operators::Vocabulary.force_refresh!
            q = cdb.query([ "example", "12" ])
            assert_match(/EXAMPLE/, q.sql)
          end
        end
      end
    end
  end
end

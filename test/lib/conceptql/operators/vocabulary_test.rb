require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file in gdm" do
    assert ConceptQL::Operators.operators[:gdm]["admsrce"]
  end

  it "should populate known aliases for vocabularies from file in gdm" do
    assert ConceptQL::Operators.operators[:gdm]["revenue code"]
  end

  it "should have a description" do
    assert ConceptQL::Operators.operators[:gdm]["admsrce"].standard_description
  end

  it "should have arguments" do
    assert ConceptQL::Operators.operators[:gdm]["admsrce"].to_metadata("admsrce")[:arguments].present?
  end

  it "should have aliases" do
    assert ConceptQL::Operators.operators[:gdm]["admsrce"].to_metadata("admsrce")[:aliases].empty?
    assert ConceptQL::Operators.operators[:gdm]["icd9cm"].to_metadata("admsrce")[:aliases].present?
  end

  it "should have predominant_domains set to correct value" do
    assert ConceptQL::Operators.operators[:gdm]["icd9cm"].to_metadata("icd9cm")[:predominant_domains] == [["condition_occurrence"]]
    assert ConceptQL::Operators.operators[:gdm]["hcpcs"].to_metadata("icd9cm")[:predominant_domains] == [["procedure_occurrence"]]
    assert ConceptQL::Operators.operators[:gdm]["ndc"].to_metadata("icd9cm")[:predominant_domains] == [["drug_exposure"]]
  end

  it "should populate known vocabularies from file in omopv4_plus" do
    op_names = ConceptQL::Nodifier.new(data_model: :omopv4_plus).to_metadata.map { |_, v| v[:preferred_name] }
    op_names.must_include("ATC")
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
    db.query(["atc", "*"]).sql.must_match %Q{"clinical_code_vocabulary_id" = 'ATC'}
  end

  it "should produce correct SQL for select all under omopv4_plus" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :omopv4_plus)
    db.query(["atc", "*"]).sql.must_match %Q{"drug_source_vocabulary_id" = 21}
  end

  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
      entry.id == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w(id omopv4_vocabulary_id vocabulary_full_name vocabulary_short_name domain hidden format_regexp)
        csv << %w(test 0 test_full test_short test_domain) + [nil, nil]
      end
      f.rewind
      ConceptQL.stub(:custom_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
          entry.id == "test"
        end)
      end
    end
    assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
      entry.id == "test"
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
      assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
        entry.id == "example"
      end)

      ConceptQL::Database.stub(:lexicon, ConceptQL::Lexicon.new(db)) do
        refute_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
          entry.id == "example"
        end)
      end

      assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
        entry.id == "example"
      end)
    end

    it "should use proper case sensitivity for dynamic vocabularies" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      lexicon = ConceptQL::Lexicon.new(db)
      ConceptQL::Operators.stub(:operators, {gdm: {}, omopv4_plus: {}}) do
        ConceptQL::Database.stub(:lexicon, ConceptQL::Lexicon.new(db)) do
          cdb.stub(:lexicon, lexicon) do
            ConceptQL::Vocabularies::DynamicVocabularies.new.register_operators
            q = cdb.query([ "example", "12" ])
            assert_match(/EXAMPLE/, q.sql)
          end
        end
      end
    end
  end
end

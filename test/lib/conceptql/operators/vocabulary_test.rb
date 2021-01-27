require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Vocabulary do
  it "should populate known vocabularies from file in gdm" do
    assert ConceptQL::Operators.operators[:gdm]["admsrce"]
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

  describe "under gdm" do
    let :cdb do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    end

    it "should handle aliases in a statement" do
      assert cdb.query(["revenue code", "001"])
      assert cdb.query(["revenue_code", "001"])
    end

    it "should produce correct SQL" do
      _(cdb.query(["admsrce", "12"]).sql).must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\", CAST(\"clinical_code_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ADMSRCE') AND (\"concept_code\" IN ('12')))))) AS \"t1\") AS \"t1\""
    end

    it "should produce correct SQL for older selection operators" do
      _(cdb.query(["icd9", "412"]).sql).must_equal "SELECT * FROM (SELECT * FROM (SELECT \"patient_id\" AS \"person_id\", \"id\" AS \"criterion_id\", CAST('clinical_codes' AS text) AS \"criterion_table\", CAST('condition_occurrence' AS text) AS \"criterion_domain\", \"start_date\", \"end_date\", CAST(\"clinical_code_source_value\" AS text) AS \"source_value\", CAST(\"clinical_code_vocabulary_id\" AS text) AS \"source_vocabulary_id\" FROM \"clinical_codes\" WHERE (\"clinical_code_concept_id\" IN (SELECT \"id\" FROM \"concepts\" WHERE ((\"vocabulary_id\" = 'ICD9CM') AND (\"concept_code\" IN ('412')))))) AS \"t1\") AS \"t1\""
    end

    it "should produce correct SQL for select all" do
      _(cdb.query(["atc", "*"]).sql).must_match %Q{"clinical_code_vocabulary_id" = 'ATC'}
    end

  end

  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
      entry.id == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w(id vocabulary_full_name vocabulary_short_name domain hidden format_regexp)
        csv << %w(test test_full test_short test_domain) + [nil, nil]
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
    let(:db) do 
      db = Sequel.connect("sqlite:/")
      ConceptQL.db_extensions(db)
      # It took me 2 hours to determine that I need to wrap the Sequel::Database
      # instance in a proc because it responds to #call which
      # causes Minitest's mock framework to call it with no arguments
      # to produce an error with no strack trace that looks like:
      # ArgumentError: wrong number of arguments (given 0, expected 1..2)
      #   /usr/lib/ruby/gems/2.7.0/gems/sequel-5.40.0/lib/sequel/database/query.rb:35:in `call'
      # But we avoid this issue if we wrap the instance in a proc...UGH
      proc { db }
    end

    before do
      db.call.create_table!(:vocabularies) do
        String :id
        String :vocabulary_name
        String :domain
      end

      db.call[:vocabularies].multi_insert([
        { id: "EXAMPLE", vocabulary_name: "Example Vocabulary", domain: "measurement" }
      ])
    end

    it "should read from lexicon" do
      assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
        entry.id == "example"
      end)

      ConceptQL.stub(:make_lexicon_db, db) do
        dv = ConceptQL::Vocabularies::DynamicVocabularies.new
        av = dv.all_vocabs
        example_vocabs = av.select do |_, entry|
          entry.id == "example"
        end 
        refute_empty(example_vocabs)
      end

      assert_empty(ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs.select do |_, entry|
        entry.id == "example"
      end)
    end

    it "should use proper case sensitivity for dynamic vocabularies" do
      cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
      ConceptQL::Operators.stub(:operators, {gdm: {}, omopv4_plus: {}}) do
        ConceptQL.stub(:make_lexicon_db, db) do
          ConceptQL::Vocabularies::DynamicVocabularies.new.register_operators
          q = cdb.query([ "example", "12" ])
          assert_match(/EXAMPLE/, q.sql)
        end
      end
    end
  end
end

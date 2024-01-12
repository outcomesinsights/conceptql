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
      cql_sql = cdb.query(["admsrce", "12"]).sql
      assert_match(/lower\("concept_code"\) IN \('12'\)/, cql_sql)
      assert_match(/"vocabulary_id" = 'ADMSRCE'/, cql_sql)
      assert_match(/"clinical_code_concept_id" IN \(SELECT/, cql_sql)
    end

    it "should produce correct SQL for select all" do
      cql_sql = cdb.query(["atc", "*"]).sql
      assert_match(/"clinical_code_vocabulary_id" = 'ATC'/, cql_sql)
      assert_match(/"clinical_code_concept_id" != 0/, cql_sql)
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

  describe "with example GDM vocabularies" do
    let(:db) { Sequel.connect("sqlite:/") }

    before do
      if ENV["LEXICON_GDM_ONLY"].present?
        db.create_table!(:vocabularies) do
          String :id
          String :vocabulary_name
          String :domain
        end
        # These are needed to fake out Lexicon
        db.create_table!(:ancestors) { String :column }
        db.create_table!(:concepts) { String :column }
        db.create_table!(:mappings) { String :column }
        db[:vocabularies].multi_insert([
          { id: "EXAMPLE", vocabulary_name: "Example Vocabulary", domain: "measurement" }
        ])
      else
        db.create_table!(:vocabulary) do
          String :vocabulary_id
          String :vocabulary_name
        end
        # These are needed to fake out Lexicon
        db.create_table!(:concept_ancestor) { String :column }
        db.create_table!(:concept) { String :column }
        db.create_table!(:concept_relationship) { String :column }
        db[:vocabulary].multi_insert([
          { vocabulary_id: "EXAMPLE", vocabulary_name: "Example Vocabulary" }
        ])
      end
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
      ConceptQL::Operators.stub(:operators, {gdm: {}, omopv4_plus: {}, gdm_wide: {}}) do
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

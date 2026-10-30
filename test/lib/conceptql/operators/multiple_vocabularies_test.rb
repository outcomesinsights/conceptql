# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::MultipleVocabularies do
  it "should appear for both GDM" do
    _(ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm).operators["cpt_or_hcpcs"]).must_equal ConceptQL::Operators::MultipleVocabularies
  end

  it "should produce correct SQL under gdm" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    sql = db.query(%w[cpt_or_hcpcs 99214]).sql
    _(sql).must_match(/"clinical_code_vocabulary_id" = 'HCPCS'/)
    _(sql).must_match(/"clinical_code_vocabulary_id" = 'CPT4'/)
  end

  it "skips CPT4_HCPCS on a Database whose lexicon lacks it" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)

    _(db.operators.key?("cpt4_hcpcs")).must_equal false
    _(db.query(%w[cpt_or_hcpcs 99214]).sql).wont_match(/CPT4_HCPCS/)
  end

  it "includes CPT4_HCPCS when the lexicon has it" do
    lexicon_db = Sequel.connect("sqlite:/").tap do |ldb|
      ldb.create_table!(:vocabulary) do
        String :vocabulary_id
        String :vocabulary_name
      end
      ldb.create_table!(:concept_ancestor) { String :column }
      ldb.create_table!(:concept) do
        Integer :concept_id
        String :concept_code
        String :concept_name
        String :vocabulary_id
      end
      ldb.create_table!(:concept_relationship) { String :column }
      ldb[:vocabulary].insert(vocabulary_id: "CPT4_HCPCS", vocabulary_name: "CPT4 and HCPCS")
    end
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                               lexicon: ConceptQL::Lexicon.new(lexicon_db))
    sql = db.query(%w[cpt_or_hcpcs 99214]).sql

    _(db.query(%w[cpt4_hcpcs 99214]).sql).must_match(/'procedure_occurrence' AS \w+\) AS "criterion_domain"/)
    _(sql).must_match(/"clinical_code_vocabulary_id" = 'CPT4_HCPCS'/)
    _(sql).must_match(/"clinical_code_vocabulary_id" = 'CPT4'/)
    _(sql).must_match(/"clinical_code_vocabulary_id" = 'HCPCS'/)
  end

  it "has no icd10 operator" do
    _(ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm).operators.key?("icd10")).must_equal false
  end

  it "should read operators from a custom file" do
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
      row.first[:operator] == "test"
    end)
    Tempfile.create("blah.csv") do |f|
      CSV(f) do |csv|
        csv << %w[operator vocabulary_id domain]
        csv << %w[test test_id test_domain]
      end
      f.rewind
      ConceptQL.stub(:custom_multiple_vocabularies_file_path, Pathname.new(f.path)) do
        refute_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
          row.first[:operator] == "test"
        end)
      end
    end
    assert_empty(ConceptQL::Operators::MultipleVocabularies.get_multiple_vocabularies.select do |_key, row|
      row.first[:operator] == "test"
    end)
  end

  describe "code warnings" do
    let(:operator) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
                         .query(%w[cpt_or_hcpcs 99214 12345 AA0382 A9999]).operator
    end

    # Sets each vocabulary operator's warnings as validation would leave them.
    def vocab_warnings(by_vocabulary)
      operator.vocab_ops.each do |vocab_op|
        vocab_op.instance_variable_set(:@warnings, by_vocabulary.fetch(vocab_op.op_name))
      end
      operator.code_warnings
    end

    it "calls a code unknown when one vocabulary rejects its format and another does not know it" do
      warnings = vocab_warnings(
        "cpt4" => [ [ "improperly formatted code", "AA0382" ], [ "unknown code(s)", "12345", "A9999" ] ],
        "hcpcs" => [ [ "improperly formatted code", "99214", "12345", "AA0382" ], [ "unknown code(s)", "A9999" ] ]
      )

      _(warnings).must_equal [ [ "improperly formatted code", "AA0382" ], [ "unknown code(s)", "12345", "A9999" ] ]
    end

    it "does not warn about a code that one vocabulary accepts" do
      warnings = vocab_warnings(
        "cpt4" => [ [ "unknown code(s)", "12345" ] ],
        "hcpcs" => [ [ "improperly formatted code", "99214", "12345" ] ]
      )

      _(warnings).must_equal [ [ "unknown code(s)", "12345" ] ]
    end

    it "keeps a vocabulary operator's own warnings intact" do
      cpt4 = [ [ "unknown code(s)", "12345" ] ]
      vocab_warnings("cpt4" => cpt4, "hcpcs" => [ [ "improperly formatted code", "12345" ] ])
      operator.aggregate_messages([ cpt4 ])

      _(cpt4).must_equal [ [ "unknown code(s)", "12345" ] ]
    end
  end
end

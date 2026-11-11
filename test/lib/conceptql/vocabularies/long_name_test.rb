# frozen_string_literal: true

require_relative "../../../db_helper"

# config/vocabularies.csv and the OHDSI lexicon give a vocabulary's long name in
# the column vocabulary_full_name. Entry read vocabulary_long_name, which only
# DrgSystems set, so every other vocabulary's long_name was its short name
# (bead conceptql-txmo). The long_name goes into the operator's metadata.
describe "the long name of a vocabulary" do
  let(:vocabs) { ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs }

  def metadata(cdb, name)
    cdb.operators(:gdm).fetch(name).to_metadata(name)
  end

  it "is the vocabulary_full_name of config/vocabularies.csv" do
    _(vocabs.fetch("atc").long_name).must_equal "WHO Anatomic Therapeutic Chemical Classification"
    _(vocabs.fetch("cpt4").long_name).must_equal "Current Procedural Terminology version 4 (AMA)"
    _(vocabs.fetch("drg").long_name).must_equal "Diagnosis-related group (CMS)"
  end

  it "does not change the short name" do
    _(vocabs.fetch("atc").short_name).must_equal "WHO ATC"
    _(vocabs.fetch("cpt4").short_name).must_equal "CPT"
  end

  # A row without a short name keeps no short name: the operator's
  # preferred_name falls back to the vocabulary ID, as before.
  it "is not the short name of a vocabulary without one" do
    _(vocabs.fetch("ndc").long_name).must_equal "National Drug Code (FDA and manufacturers)"
    _(vocabs.fetch("ndc").short_name).must_be_nil
  end

  it "is each DRG system's own long name" do
    _(vocabs.fetch("ms_drg").long_name).must_equal ConceptQL::Vocabularies::DrgSystems.system("ms_drg").long_name
    _(vocabs.fetch("cms_drg").long_name).must_equal ConceptQL::Vocabularies::DrgSystems.system("cms_drg").long_name
    _(vocabs.fetch("ms_drg").short_name).must_equal "MS-DRG"
  end

  it "is the long_name of the operator's metadata" do
    cdb = ConceptQL::Database.new(nil, data_model: :gdm)

    _(metadata(cdb, "atc")[:long_name]).must_equal "WHO Anatomic Therapeutic Chemical Classification"
    _(metadata(cdb, "atc")[:short_name]).must_equal "WHO ATC"
    _(metadata(cdb, "ms_drg")[:long_name]).must_equal ConceptQL::Vocabularies::DrgSystems.system("ms_drg").long_name
  end

  # bead conceptql-rx42: the spec's table of the vocabulary operators shows
  # each long_name, so no published vocabulary operator may lack one
  it "is set for read and for a multiple vocabulary operator" do
    cdb = ConceptQL::Database.new(nil, data_model: :gdm)

    _(metadata(cdb, "read")[:long_name]).must_equal "NHS UK Read Codes Version 2 (HSCIC)"
    _(metadata(cdb, "read")[:predominant_domains]).must_equal [ "condition_occurrence" ]
    _(metadata(cdb, "cpt_or_hcpcs")[:long_name]).must_equal "CPT4, HCPCS and CPT4_HCPCS"
    blank = ConceptQL.metadata(cdb)[:operators].values.select { |op| op[:spec_id] == "vocabulary-operator" && op[:long_name].to_s.strip.empty? }
    _(blank.map { |op| op[:name] }).must_be_empty
  end

  describe "with an OHDSI lexicon" do
    let(:ldb) do
      Sequel.connect("sqlite:/").tap do |ldb|
        ldb.create_table!(:vocabulary) do
          String :vocabulary_id
          String :vocabulary_name
        end
        ldb.create_table!(:concept) do
          Integer :concept_id
          String :vocabulary_id
          String :concept_code
          String :concept_name
        end
        ldb.create_table!(:concept_ancestor) { Integer :ancestor_concept_id }
        ldb.create_table!(:concept_relationship) { Integer :concept_id_1 }
        ldb[:vocabulary].import(%i[vocabulary_id vocabulary_name],
                                [ %w[LEX_ONLY Lexicon\ Only], %w[ATC Lexicon\ ATC] ])
      end
    end

    let(:cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                            lexicon: ConceptQL::Lexicon.new(nil, strategy: ConceptQL::LexiconOhdsi.new(ldb)))
    end

    it "is the lexicon's vocabulary_name for a vocabulary that only the lexicon has" do
      _(metadata(cdb, "lex_only")[:long_name]).must_equal "Lexicon Only"
    end

    it "is the CSV's vocabulary_full_name for a vocabulary that the CSV also has" do
      _(metadata(cdb, "atc")[:long_name]).must_equal "WHO Anatomic Therapeutic Chemical Classification"
    end
  end
end

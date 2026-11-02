# frozen_string_literal: true

require_relative "../../../db_helper"

# The GDM vocabulary table gives a vocabulary without a domain the domain ''
# (40 of the 41 vocabularies of the gdm_vocabs test data). A blank domain is
# no domain, so the vocabulary selects condition_occurrence records, as a
# vocabulary of the OHDSI lexicon (whose domain is NULL) does (bead
# conceptql-7azx). Before, its operators got criterion_domain ''.
describe "a vocabulary whose domain is blank" do
  def entry(hash)
    ConceptQL::Vocabularies::Entry.new({ id: "FOO" }.merge(hash))
  end

  it "has no domain" do
    [ "", " " ].each do |blank|
      blank_entry = entry(domain: blank)

      _(blank_entry.domain).must_be_nil
      _(blank_entry.has_domain?).must_equal false
      _(blank_entry.predominant_domains).must_equal %w[condition_occurrence]
      _(blank_entry.to_hash[:domain]).must_be_nil
    end
  end

  it "keeps a domain that is not blank" do
    _(entry(domain: "drug_exposure").predominant_domains).must_equal %w[drug_exposure]
    _(entry({}).predominant_domains).must_equal %w[condition_occurrence]
  end

  it "does not replace a domain when it is merged over it" do
    _(entry(domain: "procedure_occurrence").merge(entry(domain: "")).domain).must_equal "procedure_occurrence"
  end

  # In the gdm_vocabs config, cms_place_of_service is one of the
  # vocabularies with domain ''. The other configs give it no domain.
  it "gives cms_place_of_service the domain condition_occurrence in every config" do
    statement = [ "cms_place_of_service", "21" ]

    _(CDB.query(statement).operator.domain).must_equal :condition_occurrence
    _(CDB.query(statement).query.select_map(:criterion_domain).uniq - [ "condition_occurrence" ]).must_be_empty
  end

  describe "in a GDM lexicon" do
    let(:ldb) do
      Sequel.connect("sqlite:/").tap do |ldb|
        ldb.create_table!(:vocabularies) do
          String :id
          String :vocabulary_name
          String :domain
        end
        ldb.create_table!(:concepts) do
          Integer :id
          String :vocabulary_id
          String :concept_code
          String :concept_text
        end
        ldb.create_table!(:ancestors) { Integer :ancestor_id }
        ldb.create_table!(:mappings) { Integer :concept_1_id }
        ldb[:vocabularies].import(%i[id vocabulary_name domain],
                                  [ %w[GDM_BLANK Blank] + [ "" ], %w[GDM_DRUG Drug drug_exposure] ])
        ldb[:concepts].import(%i[id vocabulary_id concept_code concept_text],
                              [ [ 1, "GDM_BLANK", "B1", "Blank 1" ], [ 2, "GDM_DRUG", "D1", "Drug 1" ] ])
      end
    end

    let(:cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                            lexicon: ConceptQL::Lexicon.new(nil, strategy: ConceptQL::LexiconGDM.new(ldb)))
    end

    it "gives the operator the domain condition_occurrence" do
      operator = cdb.query(%w[gdm_blank B1]).operator

      _(operator.domain).must_equal :condition_occurrence
      _(operator.domains(nil)).must_equal %i[condition_occurrence]
      _(cdb.query(%w[gdm_blank B1]).sql).must_match(/'condition_occurrence' AS text\) AS "criterion_domain"/)
    end

    it "lists condition_occurrence as the operator's predominant domain" do
      operators = cdb.operators(:gdm)

      _(operators.fetch("gdm_blank").to_metadata("gdm_blank")[:predominant_domains]).must_equal %w[condition_occurrence]
      _(operators.fetch("gdm_drug").to_metadata("gdm_drug")[:predominant_domains]).must_equal %w[drug_exposure]
    end
  end
end

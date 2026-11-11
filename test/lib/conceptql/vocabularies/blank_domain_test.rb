# frozen_string_literal: true

require_relative "../../../db_helper"

# A vocabulary whose domain is blank ('' or spaces) has no domain. It selects
# condition_occurrence records, as a vocabulary of the OHDSI lexicon (whose
# domain is NULL) does (bead conceptql-7azx). Before, its operators got
# criterion_domain ''. The removed GDM lexicon gave most of its vocabularies
# the domain '', and a lexicon or a vocabulary file can still give one.
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

  # The OHDSI lexicon gives cms_place_of_service no domain.
  it "gives cms_place_of_service the domain condition_occurrence" do
    statement = [ "cms_place_of_service", "21" ]

    _(CDB.query(statement).operator.domain).must_equal :condition_occurrence
    _(CDB.query(statement).query.select_map(:criterion_domain).uniq - [ "condition_occurrence" ]).must_be_empty
  end

  # The OHDSI vocabulary table has no domain column, so this lexicon's
  # vocabulary rows take their domains from the test.
  describe "in a lexicon that gives a blank domain" do
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
        ldb[:vocabulary].import(%i[vocabulary_id vocabulary_name], [ %w[LEX_BLANK Blank], %w[LEX_DRUG Drug] ])
        ldb[:concept].import(%i[concept_id vocabulary_id concept_code concept_name],
                             [ [ 1, "LEX_BLANK", "B1", "Blank 1" ], [ 2, "LEX_DRUG", "D1", "Drug 1" ] ])
      end
    end

    let(:strategy) do
      domains = { "LEX_BLANK" => "", "LEX_DRUG" => "drug_exposure" }
      ConceptQL::LexiconOhdsi.new(ldb).tap do |strategy|
        strategy.define_singleton_method(:vocabularies) do
          super().map { |row| row.merge(domain: domains.fetch(row[:id])) }
        end
      end
    end

    let(:cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                            lexicon: ConceptQL::Lexicon.new(nil, strategy: strategy))
    end

    it "gives the operator the domain condition_occurrence" do
      operator = cdb.query(%w[lex_blank B1]).operator

      _(operator.domain).must_equal :condition_occurrence
      _(operator.domains(nil)).must_equal %i[condition_occurrence]
      _(cdb.query(%w[lex_blank B1]).sql).must_match(/'condition_occurrence' AS text\) AS "criterion_domain"/)
    end

    it "lists condition_occurrence as the operator's predominant domain" do
      operators = cdb.operators(:gdm)

      _(operators.fetch("lex_blank").to_metadata("lex_blank")[:predominant_domains]).must_equal %w[condition_occurrence]
      _(operators.fetch("lex_drug").to_metadata("lex_drug")[:predominant_domains]).must_equal %w[drug_exposure]
    end
  end
end

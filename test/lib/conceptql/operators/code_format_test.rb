# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql"

# Each format_regexp in config/vocabularies.csv is a vocabulary_formats
# validator row, anchored with ^...$. The real codes below are concept_codes of
# that vocabulary in the OHDSI vocabulary of the DuckDB test fixture.
# ICD10PCS uses the ICD10PCS.BILLABLE row: 7 characters, a real section
# character first, so hierarchy parents (0016) and Z561123 are malformed.
describe "vocabulary code formats" do
  # CPT4_HCPCS has an operator only when the lexicon carries it.
  let(:lexicon_db) do
    Sequel.connect("sqlite:/").tap do |ldb|
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
  end

  let(:cdb) do
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                          lexicon: ConceptQL::Lexicon.new(lexicon_db))
  end

  def badly_formatted(statement)
    operator = cdb.query(statement).operator
    operator.valid?(cdb.db)
    operator.warnings.select { |message, *| message == "improperly formatted code" }.flat_map { |_, *codes| codes }
  end

  # operator => [real codes, malformed codes]
  {
    "cpt4" => [ %w[M0201 99214 0001A], %w[0382 AA0382] ],
    "cpt4_hcpcs" => [ %w[M0201 0552U 99214 A2040], %w[0382 AA0382] ],
    "hcpcs" => [ %w[A0382 A2001], %w[99214 0382] ],
    "icd10who" => [ %w[A20 A30.8 A15-A19 II], %w[1A0 A20.12345] ],
    "icd10cm" => [ %w[E58 Y36.101A M10.142 QA0], %w[E1165 1A0] ],
    "icd10pcs" => [ %w[00163ZB XW03368 03JY3ZZ], %w[Z561123 561123 0016 00163ZI] ],
    "icd9cm" => [ %w[412 V62.3 E873.1], %w[4011 00.00] ],
    "icd9proc" => [ %w[00.01 01.6 00], %w[4523 0001] ],
    "atc" => [ %w[A A01 A01AB02], %w[E01 A01AB023] ],
    "drg" => [ %w[001 210], %w[1 0001] ],
    "icd03_morphology" => [ %w[8000/0 8001/0], %w[8000 800] ],
    "icd03_topography" => [ %w[C00.0 C00.1], %w[C509 C00.123] ],
    "ndc" => [ %w[43742164901 003630641 00019N068], %w[0002-7510-01 1234567] ],
    "rxnorm" => [ %w[161 2714520], %w[1 123456789] ],
    "snomed" => [ %w[22298006 70685003], %w[12345 27d654d1-c02e-444b-bafc-4e6c0b49dba3] ]
  }.each do |operator, (real, malformed)|
    it "accepts real #{operator} codes and flags malformed ones" do
      _(badly_formatted([ operator, *real, *malformed ])).must_equal malformed
    end
  end

  it "accepts M0201, which the old CPT4 pattern rejected" do
    _(badly_formatted(%w[cpt M0201])).must_be_empty
  end

  it "matches a whole code, not a code inside a longer string" do
    _(badly_formatted([ "cpt4", "99214 and more" ])).must_equal [ "99214 and more" ]
  end

  it "ignores case, as before" do
    _(badly_formatted(%w[hcpcs a0382])).must_be_empty
    _(badly_formatted(%w[icd10cm e58 y36.101a])).must_be_empty
  end

  it "does not check formats in a select-all statement" do
    _(badly_formatted(%w[hcpcs * 99214])).must_be_empty
    _(badly_formatted(%w[hcpcs 99214])).must_equal [ "99214" ]
  end
end

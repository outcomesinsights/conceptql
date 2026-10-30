# frozen_string_literal: true

require_relative "../../../helper"
require "conceptql"

# The code formats come from config/vocabulary_formats.tsv, a pinned copy of
# the vocabulary_formats table (bead conceptql-bns). Each vocabulary uses its
# DEFAULT row, anchored as \A(?:pattern)\z. A vocabulary without a row gets no
# format check. The real codes below are concept_codes of that vocabulary in the
# OHDSI vocabulary of the DuckDB test fixture. The ICD10PCS default row admits
# the hierarchy parents (0016) and any 1 to 7 characters of the PCS alphabet,
# which has no I and no O.
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
      ldb[:vocabulary].insert(vocabulary_id: "RxNorm Extension", vocabulary_name: "RxNorm Extension")
    end
  end

  let(:cdb) do
    ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm,
                                                          lexicon: ConceptQL::Lexicon.new(lexicon_db))
  end

  # The NDC warning adds a reason after the plain text (bead conceptql-28h),
  # so this matches the start of the message.
  def badly_formatted(statement)
    operator = cdb.query(statement).operator
    operator.valid?(cdb.db)
    operator.warnings.select { |message, *| message.start_with?("improperly formatted code") }
            .flat_map { |_, *codes| codes }
  end

  # operator => [real codes, malformed codes]
  {
    "cpt4" => [ %w[M0201 99214 0001A], %w[0382 AA0382] ],
    "cpt4_hcpcs" => [ %w[M0201 0552U 99214 A2040], %w[0382 AA0382] ],
    "hcpcs" => [ %w[A0382 A2001], %w[99214 0382] ],
    "icd10who" => [ %w[A20 A30.8 A15-A19 II], %w[1A0 A20.12345] ],
    "icd10cm" => [ %w[E58 Y36.101A M10.142 QA0], %w[E1165 1A0] ],
    "icd10pcs" => [ %w[00163ZB XW03368 03JY3ZZ 0016 0], %w[00163ZI 0016O 00163ZB1] ],
    "icd9cm" => [ %w[412 V62.3 E873.1], %w[4011 00.00] ],
    "icd9proc" => [ %w[00.01 01.6 00], %w[4523 0001] ],
    "atc" => [ %w[A A01 A01AB02], %w[E01 A01AB023] ],
    "drg" => [ %w[001 210], %w[1 0001] ],
    "ms_drg" => [ %w[001 210], %w[1 0001] ],
    "cms_drg" => [ %w[001 210], %w[1 0001] ],
    "icd03_morphology" => [ %w[8000/0 8001/0], %w[8000 800] ],
    "icd03_topography" => [ %w[C00.0 C00.1], %w[C509 C00.123] ],
    "ndc" => [ %w[43742164901], %w[0002-7510-01 1234567] ],
    "rxnorm" => [ %w[161 2714520], %w[1 123456789] ],
    "snomed" => [ %w[22298006 70685003], %w[12345 27d654d1-c02e-444b-bafc-4e6c0b49dba3] ],
    "rxnorm_extension" => [ %w[OMOP4844730], %w[4844730 OMOP12] ]
  }.each do |operator, (real, malformed)|
    it "accepts real #{operator} codes and flags malformed ones" do
      _(badly_formatted([ operator, *real, *malformed ])).must_equal malformed
    end
  end

  # conceptql's own LOINC pattern ^\w{3,7}-\w$ rejected 99 standard LOINC
  # codes, 20-8 (concept 3023414) among them. vocabulary_formats has no LOINC
  # row and no Gemscript row, so neither gets a format check.
  it "accepts the LOINC codes 20-8 and 1-8" do
    _(badly_formatted(%w[loinc 20-8 1-8])).must_be_empty
    _(cdb.query(%w[loinc 20-8]).validation_errors).must_equal({})
  end

  it "does not check the format of a vocabulary that has no vocabulary_formats row" do
    _(badly_formatted([ "loinc", "not a code" ])).must_be_empty
    _(badly_formatted(%w[gemscript !0000101 7992602])).must_be_empty
  end

  # The NDC default row is the 11-digit claims form. The fixture's 9-digit
  # product codes and the alphanumeric codes (rows NDC.COMPLETE and
  # NDC.ALPHANUM) are real concept_codes, but the default row rejects them.
  it "flags the 9-digit and alphanumeric NDC forms, as the NDC default row does" do
    _(badly_formatted(%w[ndc 003630641 00019N068 43742164901])).must_equal %w[003630641 00019N068]
  end

  # Claims carry the 11-digit package NDC. jde scanned the 601.9M NDC rows of
  # the active Jigsaw claims: 99.99% have 11 digits, and none is a 9-digit
  # product code (bead conceptql-28h, seed conceptql-ysx). So the NDC warning
  # says why the code matches nothing. The text starts with the plain
  # warning, which the JDE algorithm spec looks for.
  describe "the format warning text" do
    def format_warning(statement)
      cdb.query(statement).scope_annotate(skip_counts: true)[:warnings]
         .fetch(statement.first)
         .find { |message, *| message.start_with?("improperly formatted code") }
    end

    it "says why an NDC code in another form matches no rows" do
      _(format_warning(%w[ndc 003630641])).must_equal [
        "improperly formatted code (claims use 11-digit package NDCs, so it matches no rows)", "003630641"
      ]
    end

    it "is unchanged for another vocabulary" do
      _(format_warning(%w[icd9 410*])).must_equal [ "improperly formatted code", "410*" ]
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

  # Ryan ruled 2026-10-30 (seeds conceptql-0eb and conceptql-ysx), reversing
  # the ruling of 2026-10-29: a malformed code is a warning, not a validation
  # error, and the statement stays valid. There is no prefix matching.
  describe "a malformed code" do
    # The format warnings of scope_annotate. The lexicon above has no codes,
    # so every well-formed code also gets the warning "unknown code(s)".
    def format_warnings(statement)
      cdb.query(statement).scope_annotate(skip_counts: true)[:warnings]
         .transform_values { |warnings| warnings.select { |message, *| message == "improperly formatted code" } }
         .reject { |_, warnings| warnings.empty? }
    end

    it "is a warning that names the code, and the statement stays valid" do
      _(cdb.query(%w[icd9 410*]).validation_errors).must_equal({})
      _(format_warnings(%w[icd9 410*])).must_equal("icd9" => [ [ "improperly formatted code", "410*" ] ])
    end

    it "names only the malformed codes" do
      _(cdb.query(%w[icd9 412 410* 412.0]).validation_errors).must_equal({})
      _(format_warnings(%w[icd9 412 410* 412.0])).must_equal("icd9" => [ [ "improperly formatted code", "410*" ] ])
    end

    it "is a warning for a multiple-vocabulary operator only when every vocabulary rejects its format" do
      _(cdb.query(%w[cpt_or_hcpcs 99214 A0382 AA0382]).validation_errors).must_equal({})
      _(format_warnings(%w[cpt_or_hcpcs 99214 A0382 AA0382]))
        .must_equal("cpt_or_hcpcs" => [ [ "improperly formatted code", "AA0382" ] ])
      # 12345 is malformed for HCPCS but a well-formed CPT4 code.
      _(format_warnings(%w[cpt_or_hcpcs 12345])).must_equal({})
    end

    it "leaves the select-all wildcard valid" do
      _(cdb.query(%w[icd9 *]).validation_errors).must_equal({})
      _(cdb.query(%w[cpt_or_hcpcs *]).validation_errors).must_equal({})
    end
  end

  it "does not check formats in a select-all statement" do
    _(badly_formatted(%w[hcpcs * 99214])).must_be_empty
    _(badly_formatted(%w[hcpcs 99214])).must_equal [ "99214" ]
  end
end

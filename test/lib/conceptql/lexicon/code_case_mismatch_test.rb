# frozen_string_literal: true

require_relative "../../../helper"

# A program that looks up codes through the Lexicon (or the DataModel, which
# delegates to it) gets ConceptQL::CodeCaseMismatchError when a code matches
# no stored code exactly but matches one in another case (bead conceptql-rz8s).
# t_shank asked GDM_PROV for "line", the vocabulary stores "LINE", and the
# empty answer lost every line row of an export. A vocabulary operator in a
# statement passes check_case: false: it warns and selects nothing instead.
describe "a code lookup given a code in another case" do
  include FormatsTable

  let(:ldb) do
    Sequel.connect("sqlite:/").tap do |ldb|
      ldb.create_table!(:vocabulary) do
        String :vocabulary_id
        String :vocabulary_name
      end
      ldb.create_table!(:concept_ancestor) { String :column }
      ldb.create_table!(:concept_relationship) { String :column }
      ldb.create_table!(:concept) do
        Integer :concept_id
        String :concept_code
        String :concept_name
        String :vocabulary_id
        String :concept_class_id
      end
      ldb[:concept].import(%i[concept_id concept_code concept_name vocabulary_id concept_class_id],
                           [ [ 1, "LINE", "Line", "GDM_PROV", "Prov" ],
                             [ 2, "CLAIM", "Claim", "GDM_PROV", "Prov" ],
                             [ 3, "claim", "Claim", "JS_FILE_PROV_TYPE", "Prov" ],
                             [ 4, "cX", "cX lower", "SEER_COMBINED_T", "T" ],
                             [ 5, "CX", "CX upper", "SEER_COMBINED_T", "T" ],
                             [ 6, "I16.5", "Hypertensive crisis", "ICD10CM", "4-char billing code" ],
                             [ 7, "Line", "Line again", "GDM_PROV", "Prov" ] ])
    end
  end

  let(:lexicon) { ConceptQL::Lexicon.new(nil, ldb, strategy: ConceptQL::LexiconOhdsi.new(ldb), cache: true) }

  def mismatch(&block)
    _(block).must_raise(ConceptQL::CodeCaseMismatchError)
  end

  describe "concept_ids" do
    it "raises for a code that the vocabulary stores only in another case" do
      error = mismatch { lexicon.concept_ids(ldb, "ICD10CM", %w[i16.5]) }

      _(error.message).must_include "ICD10CM"
      _(error.message).must_include '"i16.5"'
      _(error.message).must_include '"I16.5"'
    end

    it "names every stored spelling of the code" do
      error = mismatch { lexicon.concept_ids(ldb, "GDM_PROV", %w[line]) }

      _(error.message).must_include '"LINE"'
      _(error.message).must_include '"Line"'
      _(error.mismatches).must_equal [ ConceptQL::CodeCaseMismatchError::Mismatch.new("GDM_PROV", "line", %w[LINE Line]) ]
    end

    it "names each mismatched code and only those" do
      error = mismatch { lexicon.concept_ids(ldb, "GDM_PROV", %w[LINE claim nothing]) }

      _(error.mismatches.map(&:code)).must_equal %w[claim]
      _(error.message).must_include '"CLAIM"'
      _(error.message).wont_include "nothing"
    end

    it "raises when the code is given as a String" do
      mismatch { lexicon.concept_ids(ldb, "GDM_PROV", "line") }
    end

    it "returns the concept of a code in its stored case" do
      _(lexicon.concept_ids(ldb, "GDM_PROV", %w[LINE])).must_equal [ 1 ]
      _(lexicon.concept_ids(ldb, "ICD10CM", %w[I16.5])).must_equal [ 6 ]
    end

    it "returns nothing, without an error, for a code that matches nothing in any case" do
      _(lexicon.concept_ids(ldb, "GDM_PROV", %w[nothing])).must_equal []
    end

    it "does not raise when the vocabulary stores the code in this case too" do
      _(lexicon.concept_ids(ldb, "SEER_COMBINED_T", %w[cX])).must_equal [ 4 ]
      _(lexicon.concept_ids(ldb, "SEER_COMBINED_T", %w[CX])).must_equal [ 5 ]
    end

    # One lookup over several vocabularies (the provenance types) finds a
    # code that one of them stores in this case.
    it "does not raise when another vocabulary of the lookup stores the code exactly" do
      _(lexicon.concept_ids(ldb, %w[GDM_PROV JS_FILE_PROV_TYPE], %w[claim])).must_equal [ 3 ]
    end

    it "names the vocabulary of the stored spelling in a lookup over several vocabularies" do
      error = mismatch { lexicon.concept_ids(ldb, %w[GDM_PROV JS_FILE_PROV_TYPE], %w[Claim]) }

      _(error.mismatches).must_equal [ ConceptQL::CodeCaseMismatchError::Mismatch.new("GDM_PROV", "Claim", %w[CLAIM]),
                                       ConceptQL::CodeCaseMismatchError::Mismatch.new("JS_FILE_PROV_TYPE", "Claim", %w[claim]) ]
    end

    it "returns every concept of the vocabulary for no codes" do
      _(lexicon.concept_ids(ldb, "GDM_PROV", []).sort).must_equal [ 1, 2, 7 ]
    end

    it "skips the check with check_case: false" do
      _(lexicon.concept_ids(ldb, "GDM_PROV", %w[line], check_case: false)).must_equal []
    end

    it "raises again for a repeated lookup with caching on" do
      2.times { mismatch { lexicon.concept_ids(ldb, "GDM_PROV", %w[line]) } }
    end

    it "does not raise for a vocabulary whose row declares (?i:...)" do
      with_formats_table("ICD10CM" => "(?i:[A-Z][0-9][0-9AB](\\.[0-9A-Z]{1,4})?)") do
        _(lexicon.concept_ids(ldb, "ICD10CM", %w[i16.5])).must_equal [ 6 ]
      end
    end
  end

  describe "the other lookups that take codes" do
    it "raise for a code that the vocabulary stores only in another case" do
      mismatch { lexicon.known_codes(ldb, "GDM_PROV", %w[line]) }
      mismatch { lexicon.concepts_to_codes(ldb, "GDM_PROV", %w[line]) }
      mismatch { lexicon.code_meanings(ldb, "GDM_PROV", %w[line]) }
      mismatch { lexicon.concepts_to_codes_in_class(ldb, "GDM_PROV", "Prov", %w[line]) }
      mismatch { lexicon.concepts(ldb, "GDM_PROV", %w[line]) }
      mismatch { lexicon.concepts_ds(ldb, "GDM_PROV", %w[line]) }
    end

    it "answer as before with check_case: false" do
      _(lexicon.known_codes(ldb, "GDM_PROV", %w[line LINE], check_case: false)).must_equal %w[LINE]
      _(lexicon.concepts_to_codes(ldb, "GDM_PROV", %w[line], check_case: false)).must_equal []
      _(lexicon.code_meanings(ldb, "GDM_PROV", %w[line], check_case: false)).must_equal({})
      _(lexicon.concepts_to_codes_in_class(ldb, "GDM_PROV", "Prov", %w[line], check_case: false)).must_equal []
      _(lexicon.concepts(ldb, "GDM_PROV", %w[line], check_case: false).select_map(:id)).must_equal []
      _(lexicon.concepts_ds(ldb, "GDM_PROV", %w[line], check_case: false).select_map(:concept_code)).must_equal []
    end

    it "answer as before for codes in their stored case and for unknown codes" do
      _(lexicon.known_codes(ldb, "GDM_PROV", %w[LINE nothing])).must_equal %w[LINE]
      _(lexicon.concepts_to_codes(ldb, "GDM_PROV", %w[LINE nothing])).must_equal [ %w[LINE Line] ]
      _(lexicon.concepts_to_codes_in_class(ldb, "GDM_PROV", "Prov", %w[LINE])).must_equal [ %w[LINE Line] ]
      _(lexicon.concepts(ldb, "GDM_PROV", %w[LINE]).select_map(:id)).must_equal [ 1 ]
    end
  end

  describe "through the DataModel" do
    let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm, lexicon: lexicon) }

    it "raises from concept_ids" do
      error = mismatch { cdb.data_model.concept_ids(ldb, "GDM_PROV", %w[line]) }

      _(error.message).must_include '"LINE"'
    end

    it "returns the concept of a code in its stored case" do
      _(cdb.data_model.concept_ids(ldb, "GDM_PROV", %w[LINE])).must_equal [ 1 ]
    end
  end

  it "explains the error in its message" do
    entry = ConceptQL::CodeCaseMismatchError::Mismatch
    error = ConceptQL::CodeCaseMismatchError.new([ entry.new("GDM_PROV", "line", %w[LINE]),
                                                   entry.new("GDM_PROV", "claim", %w[CLAIM Claim]) ])

    _(error.message).must_equal <<~MESSAGE.chomp
      A code lookup got codes that their vocabulary stores only in another case.
      ConceptQL compares codes case-exactly, so these codes would match no concept:
        - The vocabulary GDM_PROV stores "line" as "LINE".
        - The vocabulary GDM_PROV stores "claim" as "CLAIM" or "Claim".
      Pass each code as its vocabulary stores it.
    MESSAGE
  end
end

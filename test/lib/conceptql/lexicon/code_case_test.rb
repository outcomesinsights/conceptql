# frozen_string_literal: true

require_relative "../../../helper"

# The lexicon compares codes case-exactly, unless the vocabulary's
# vocabulary_formats row declares case-insensitivity with the scoped flag
# (?i:...) (seed conceptql-oji ruling "b", vocabulary_formats seed vfm-8k1).
# Then it compares lower(concept_code) with the code in lower case. No row of
# the pinned table declares it, so the declared case uses a substitute table.
describe "the case of a code in a lexicon lookup" do
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
                           [ [ 1, "I16.5", "Hypertensive crisis", "ICD10CM", "4-char billing code" ],
                             [ 2, "cX", "cX", "SEER_COMBINED_T", "T" ],
                             [ 3, "inpatient", "Inpatient", "JS_FILE_PROV_TYPE", "Prov" ] ])
    end
  end

  let(:lexicon) { ConceptQL::LexiconOhdsi.new(ldb) }

  def ids(vocabulary_id, *codes)
    lexicon.concept_ids(ldb, vocabulary_id, codes)
  end

  it "selects a code only in its own case" do
    _(ids("ICD10CM", "I16.5")).must_equal [ 1 ]
    _(ids("ICD10CM", "i16.5")).must_be_empty
    _(ids("SEER_COMBINED_T", "cX")).must_equal [ 2 ]
    _(ids("SEER_COMBINED_T", "CX")).must_be_empty
    _(ids("JS_FILE_PROV_TYPE", "inpatient")).must_equal [ 3 ]
    _(ids("JS_FILE_PROV_TYPE", "Inpatient")).must_be_empty
  end

  it "describes a code only in its own case" do
    _(lexicon.concepts_to_codes(ldb, "ICD10CM", %w[I16.5 i16.5])).must_equal [ [ "I16.5", "Hypertensive crisis" ] ]
  end

  it "names a code of a concept class only in its own case" do
    _(lexicon.concepts_to_codes_in_class(ldb, "ICD10CM", "4-char billing code", %w[i16.5])).must_be_empty
    _(lexicon.concepts_to_codes_in_class(ldb, "ICD10CM", "4-char billing code", %w[I16.5]))
      .must_equal [ [ "I16.5", "Hypertensive crisis" ] ]
  end

  it "knows a code only in its own case" do
    _(lexicon.known_codes(ldb, "ICD10CM", %w[I16.5 i16.5])).must_equal %w[I16.5]
  end

  it "compares the code exactly in SQL" do
    sql = lexicon.concepts(ldb, "ICD10CM", %w[I16.5]).sql

    _(sql).must_match(/`concept_code` IN \('I16.5'\)/)
    _(sql).wont_match(/lower/i)
  end

  describe "for a vocabulary whose row declares (?i:...)" do
    let(:declared) { { "ICD10CM" => "(?i:[A-Z][0-9][0-9AB](\\.[0-9A-Z]{1,4})?)" } }

    it "selects a code in either case" do
      with_formats_table(declared) do
        _(ids("ICD10CM", "i16.5")).must_equal [ 1 ]
        _(ids("ICD10CM", "I16.5")).must_equal [ 1 ]
        _(lexicon.concepts_to_codes(ldb, "ICD10CM", %w[i16.5])).must_equal [ [ "I16.5", "Hypertensive crisis" ] ]
        _(lexicon.concepts_to_codes_in_class(ldb, "ICD10CM", "4-char billing code", %w[i16.5]))
          .must_equal [ [ "I16.5", "Hypertensive crisis" ] ]
        _(lexicon.concepts(ldb, "ICD10CM", %w[i16.5]).sql).must_match(/lower\(`concept_code`\) IN \('i16.5'\)/)
      end
    end

    it "keeps the other vocabularies case-exact" do
      with_formats_table(declared.merge("SEER_COMBINED_T" => "[cp][0-9A-Z]+")) do
        _(ids("SEER_COMBINED_T", "CX")).must_be_empty
        _(ids("JS_FILE_PROV_TYPE", "Inpatient")).must_be_empty
      end
    end

    # One lookup over several vocabularies (the provenance types) has one
    # comparison, so the vocabularies must agree on case.
    it "refuses one lookup over vocabularies that disagree on case" do
      with_formats_table(declared) do
        error = _ { lexicon.concepts(ldb, %w[ICD10CM SEER_COMBINED_T], %w[I16.5]) }.must_raise ArgumentError
        _(error.message).must_match(/ICD10CM/)
      end
    end
  end
end

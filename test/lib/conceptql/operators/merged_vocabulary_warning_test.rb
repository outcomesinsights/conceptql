# frozen_string_literal: true

require_relative "../../../helper"

# Production ETL data stores CPT-4 and HCPCS codes only under the merged
# vocabulary CPT4_HCPCS. cpt and hcpcs read only CPT4 and HCPCS, so they
# select no rows there (known issue conceptql-rpy3). They warn and name
# cpt_or_hcpcs, which reads CPT4_HCPCS (bead conceptql-k5ho). The test
# fixtures have CPT4 and HCPCS rows, so these tests use a small sqlite
# database that is both the data database and the OHDSI lexicon.
describe "the warning for a vocabulary that the data stores as a merged vocabulary" do
  def database(data_vocabularies:, lexicon_vocabularies: %w[CPT4 HCPCS CPT4_HCPCS])
    db = Sequel.connect("sqlite:/")
    db.create_table(:vocabulary) do
      String :vocabulary_id
      String :vocabulary_name
    end
    db.create_table(:concept_ancestor) { String :column }
    db.create_table(:concept_relationship) { String :column }
    db.create_table(:concept) do
      Integer :concept_id
      String :concept_code
      String :concept_name
      String :vocabulary_id
    end
    db.create_table(:patients) { Integer :id }
    db.create_table(:clinical_codes) do
      Integer :id
      Integer :clinical_code_concept_id
      String :clinical_code_vocabulary_id
    end
    lexicon_vocabularies.each_with_index do |vocabulary_id, i|
      db[:vocabulary].insert(vocabulary_id: vocabulary_id, vocabulary_name: vocabulary_id)
      db[:concept].insert(concept_id: i + 1, concept_code: code_of(vocabulary_id), concept_name: "A name",
                          vocabulary_id: vocabulary_id)
    end
    data_vocabularies.each_with_index do |vocabulary_id, i|
      db[:clinical_codes].insert(id: i + 1, clinical_code_concept_id: i + 1, clinical_code_vocabulary_id: vocabulary_id)
    end
    ConceptQL::Database.new(db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(db))
  end

  def code_of(vocabulary_id)
    vocabulary_id == "HCPCS" ? "A0425" : "99214"
  end

  def warnings_for(cdb, statement)
    cdb.query(statement).scope_annotate(skip_counts: true)[:warnings].to_h
  end

  def merged_warning(vocabulary_id)
    [ ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA,
      "the data stores #{vocabulary_id} codes as CPT4_HCPCS, so use cpt_or_hcpcs" ]
  end

  it "warns for cpt and hcpcs when the data has only CPT4_HCPCS rows" do
    cdb = database(data_vocabularies: %w[CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt 99214])).must_equal({ "cpt" => [ merged_warning("CPT4") ] })
    _(warnings_for(cdb, %w[hcpcs A0425])).must_equal({ "hcpcs" => [ merged_warning("HCPCS") ] })
  end

  it "warns for the code * too" do
    cdb = database(data_vocabularies: %w[CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt *])).must_equal({ "cpt" => [ merged_warning("CPT4") ] })
  end

  it "gives no warning for cpt_or_hcpcs or cpt4_hcpcs" do
    cdb = database(data_vocabularies: %w[CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt_or_hcpcs 99214])).must_be_empty
    _(warnings_for(cdb, %w[cpt4_hcpcs 99214])).must_be_empty
  end

  it "gives no warning when the data has rows of the operator's own vocabulary" do
    cdb = database(data_vocabularies: %w[CPT4 HCPCS CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt 99214])).must_be_empty
    _(warnings_for(cdb, %w[hcpcs A0425])).must_be_empty
  end

  it "warns only for the vocabulary that has no rows" do
    cdb = database(data_vocabularies: %w[CPT4 CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt 99214])).must_be_empty
    _(warnings_for(cdb, %w[hcpcs A0425])).must_equal({ "hcpcs" => [ merged_warning("HCPCS") ] })
  end

  it "gives no warning when the data has no CPT4_HCPCS rows" do
    cdb = database(data_vocabularies: [])

    _(warnings_for(cdb, %w[cpt 99214])).must_be_empty
  end

  it "gives no warning when the lexicon does not carry CPT4_HCPCS" do
    cdb = database(data_vocabularies: %w[CPT4_HCPCS], lexicon_vocabularies: %w[CPT4 HCPCS])

    _(warnings_for(cdb, %w[cpt 99214])).must_be_empty
  end

  it "gives no warning on a mock database" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)

    _(warnings_for(cdb, %w[cpt 99214])).must_be_empty
  end
end

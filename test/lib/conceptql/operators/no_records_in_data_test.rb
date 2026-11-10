# frozen_string_literal: true

require_relative "../../../helper"

# GDM's etl_vocabulary_ids lists the vocabularies of the data's clinical
# codes. A vocabulary operator whose vocabulary is not in it warns that the
# data has no records of the vocabulary, and its counts are null (bead
# conceptql-d1bd). These tests use a small sqlite database that is both the
# data database and the OHDSI lexicon, so each test can choose the table's
# rows, or leave the table out. They annotate with skip_counts, because the
# sqlite tables do not have every GDM column. no_records_counts_test.rb counts
# rows on the test fixture.
describe "the warning for a vocabulary that the data does not contain" do
  def no_records = ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA

  # etl_vocabulary_ids: nil leaves the table out, and [] makes it empty.
  def database(etl_vocabulary_ids:, data_vocabularies: %w[ICD9CM])
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
    %w[ICD9CM Gemscript CPT4 HCPCS CPT4_HCPCS].each_with_index do |vocabulary_id, i|
      db[:vocabulary].insert(vocabulary_id: vocabulary_id, vocabulary_name: vocabulary_id)
      db[:concept].insert(concept_id: i + 1, concept_code: code_of(vocabulary_id), concept_name: "A name",
                          vocabulary_id: vocabulary_id)
    end
    data_vocabularies.each_with_index do |vocabulary_id, i|
      db[:clinical_codes].insert(id: i + 1, clinical_code_concept_id: i + 1, clinical_code_vocabulary_id: vocabulary_id)
    end
    if etl_vocabulary_ids
      # The older shape of the table: no source_table and source_column.
      db.create_table(:etl_vocabulary_ids) do
        String :vocabulary_id
        Integer :n_rows
      end
      etl_vocabulary_ids.each { |vocabulary_id| db[:etl_vocabulary_ids].insert(vocabulary_id: vocabulary_id, n_rows: 1) }
    end
    ConceptQL::Database.new(db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(db))
  end

  def code_of(vocabulary_id)
    { "ICD9CM" => "412", "Gemscript" => "00003007", "HCPCS" => "A0425" }.fetch(vocabulary_id, "99214")
  end

  def warnings_for(cdb, statement)
    by_operator(cdb.query(statement).warnings)
  end

  def counts_of(cdb, statement)
    cdb.query(statement).annotate(skip_counts: true).last[:annotation][:counts]
  end

  it "warns for a vocabulary that etl_vocabulary_ids does not list, and its counts are null" do
    cdb = database(etl_vocabulary_ids: %w[ICD9CM])

    _(warnings_for(cdb, %w[gemscript 00003007])).must_equal({ "gemscript" => [ [ no_records ] ] })
    _(counts_of(cdb, %w[gemscript 00003007])).must_equal({ drug_exposure: { rows: nil, n: nil } })
  end

  it "gives no warning and keeps the counts for a vocabulary that etl_vocabulary_ids lists" do
    cdb = database(etl_vocabulary_ids: %w[ICD9CM])

    _(warnings_for(cdb, %w[icd9 412])).must_be_empty
    _(counts_of(cdb, %w[icd9 412])).must_equal({ condition_occurrence: { rows: 0, n: 0 } })
  end

  it "gives no warning and keeps the counts when the data has no etl_vocabulary_ids, or an empty one" do
    [ nil, [] ].each do |etl_vocabulary_ids|
      cdb = database(etl_vocabulary_ids: etl_vocabulary_ids)

      _(warnings_for(cdb, %w[gemscript 00003007])).must_be_empty
      _(counts_of(cdb, %w[gemscript 00003007])).must_equal({ drug_exposure: { rows: 0, n: 0 } })
    end
  end

  # cpt has its own warning for CPT4_HCPCS data, with the same text. It names
  # cpt_or_hcpcs, so the operator gets that warning only, once.
  it "gives cpt only the merged-vocabulary warning on CPT4_HCPCS data" do
    cdb = database(etl_vocabulary_ids: %w[CPT4_HCPCS], data_vocabularies: %w[CPT4_HCPCS])

    _(warnings_for(cdb, %w[cpt 99214])).must_equal(
      { "cpt" => [ [ no_records, "the data stores CPT4 codes as CPT4_HCPCS, so use cpt_or_hcpcs" ] ] }
    )
    _(counts_of(cdb, %w[cpt 99214])).must_equal({ procedure_occurrence: { rows: nil, n: nil } })
  end

  it "gives cpt_or_hcpcs no warning when one of its vocabularies is present" do
    [ %w[CPT4_HCPCS], %w[CPT4], %w[HCPCS] ].each do |present|
      cdb = database(etl_vocabulary_ids: present, data_vocabularies: present)

      _(warnings_for(cdb, %w[cpt_or_hcpcs 99214])).must_be_empty
      _(counts_of(cdb, %w[cpt_or_hcpcs 99214]).values.uniq).must_equal([ { rows: 0, n: 0 } ])
    end
  end

  # etl_vocabulary_ids lists the vocabularies of clinical_codes only.
  it "gives no warning for a vocabulary operator that reads another table" do
    cdb = database(etl_vocabulary_ids: %w[ICD9CM])
    cdb.db.create_table(:deaths) { Integer :id }

    _(warnings_for(cdb, %w[death_type 1]).values.flatten(1).map(&:first)).wont_include(no_records)
  end

  it "gives no warning with the lexicon but no data database" do
    lexicon = ConceptQL::Lexicon.new(database(etl_vocabulary_ids: %w[ICD9CM]).db)

    [ nil, Sequel.mock(host: :postgres) ].each do |data_db|
      cdb = ConceptQL::Database.new(data_db, data_model: :gdm, lexicon: lexicon)

      _(warnings_for(cdb, %w[gemscript 00003007])).must_be_empty
    end
  end
end

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

  # Each vocabulary branch selects different rows, so a duplicate-removing
  # UNION only costs time (conceptql-5pz).
  it "joins the vocabulary branches with UNION ALL" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide)

    [ %w[cpt_or_hcpcs *], %w[cpt_or_hcpcs 99214 A0382] ].each do |statement|
      sql = db.query(statement).sql
      _(sql.scan(/\bUNION\b/).length).must_equal 1
      _(sql).must_match(/\bUNION ALL\b/)
    end
  end

  it "keeps UNION when two branches select the same vocabulary" do
    operator = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
                                  .query(%w[cpt_or_hcpcs 99214]).operator
    cpt4 = operator.vocab_ops.first
    operator.instance_variable_set(:@vocab_ops, [ cpt4, cpt4.class.new(cpt4.nodifier, cpt4.op_name, "99214") ])

    sql = operator.sql(Sequel.mock(host: :postgres))
    _(sql).must_match(/\bUNION\b/)
    _(sql).wont_match(/\bUNION ALL\b/)
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

  # A small sqlite database is both the data database and the OHDSI
  # lexicon, so each test chooses the concepts of each vocabulary. The checks
  # treat the codes as one set across the vocabularies (bead conceptql-0h2n).
  describe "code warnings" do
    # concepts: { vocabulary_id => [code, ...] }. etl_vocabulary_ids: nil
    # leaves the table out.
    def database(concepts, etl_vocabulary_ids: %w[CPT4 HCPCS])
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
      %w[CPT4 HCPCS CPT4_HCPCS].each { |id| db[:vocabulary].insert(vocabulary_id: id, vocabulary_name: id) }
      concepts.each do |vocabulary_id, codes|
        codes.each { |code| db[:concept].insert(concept_code: code, concept_name: "A name", vocabulary_id: vocabulary_id) }
      end
      if etl_vocabulary_ids
        db.create_table(:etl_vocabulary_ids) { String :vocabulary_id }
        etl_vocabulary_ids.each { |id| db[:etl_vocabulary_ids].insert(vocabulary_id: id) }
      end
      ConceptQL::Database.new(db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(db))
    end

    def warnings_for(cdb, statement)
      by_operator(cdb.query(statement).warnings)
    end

    it "calls a code unknown when one vocabulary rejects its format and another does not know it" do
      cdb = database({ "CPT4" => %w[99214], "HCPCS" => %w[A0382] })

      _(warnings_for(cdb, %w[cpt_or_hcpcs 99214 12345 AA0382 A9999 A0382])).must_equal(
        { "cpt_or_hcpcs" => [ [ "improperly formatted code", "AA0382" ], [ "unknown code(s)", "12345", "A9999" ] ] }
      )
    end

    it "knows a code that only one vocabulary has, whichever it is" do
      cdb = database({ "CPT4" => %w[99214], "HCPCS" => %w[A0382], "CPT4_HCPCS" => %w[99215 J9999] })

      _(warnings_for(cdb, %w[cpt_or_hcpcs 99214 A0382 99215 J9999])).must_equal({})
      _(warnings_for(cdb, %w[cpt_or_hcpcs 99214 99213])).must_equal({ "cpt_or_hcpcs" => [ [ "unknown code(s)", "99213" ] ] })
    end

    # The 2020 rule (refs #185): an empty vocabulary knows every code, but
    # only when nothing tells which vocabularies the data has.
    describe "without etl_vocabulary_ids" do
      it "accepts every code when every vocabulary has no concepts" do
        _(warnings_for(database({}, etl_vocabulary_ids: nil), %w[cpt_or_hcpcs 99213 J9999])).must_equal({})
      end

      it "does not accept every code of an empty vocabulary when another vocabulary has concepts" do
        cdb = database({ "CPT4_HCPCS" => %w[99214] }, etl_vocabulary_ids: nil)

        _(warnings_for(cdb, %w[cpt_or_hcpcs 99214 99213 J9999]))
          .must_equal({ "cpt_or_hcpcs" => [ [ "unknown code(s)", "99213", "J9999" ] ] })
      end
    end

    it "does not accept every code of empty vocabularies with a filled etl_vocabulary_ids" do
      _(warnings_for(database({}), %w[cpt_or_hcpcs 99213])).must_equal({ "cpt_or_hcpcs" => [ [ "unknown code(s)", "99213" ] ] })
    end

    it "checks the codes with a lexicon and no data database" do
      lexicon = ConceptQL::Lexicon.new(database({ "CPT4" => %w[99214] }).db)
      cdb = ConceptQL::Database.new(nil, data_model: :gdm, lexicon: lexicon)

      _(warnings_for(cdb, %w[cpt_or_hcpcs 99214 99213])).must_equal({ "cpt_or_hcpcs" => [ [ "unknown code(s)", "99213" ] ] })
    end

    it "keeps a vocabulary operator's own warnings intact" do
      operator = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
                                    .query(%w[cpt_or_hcpcs 12345]).operator
      cpt4 = [ [ "unknown code(s)", "12345" ] ]
      operator.aggregate_messages([ cpt4, [ [ "improperly formatted code", "12345" ] ] ])

      _(cpt4).must_equal [ [ "unknown code(s)", "12345" ] ]
    end
  end
end

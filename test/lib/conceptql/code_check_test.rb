# frozen_string_literal: true

require_relative "../../helper"

# Database#check_codes decides the result for a code that the dataset's
# lexicon does not know (bead conceptql-dufi, seed conceptql-d9w). The 2020
# rule (refs #185) gives no code warning only when no lexicon of the Database
# has the vocabulary: the dataset's lexicon and, when it is given, the
# reference lexicon. etl_vocabulary_ids does not change the rule.
#
# Each lexicon is a small sqlite database with the OHDSI vocabulary tables, so
# each test chooses which vocabularies each lexicon has. The dataset's lexicon
# database is also the data database. 250.00 is a real ICD9CM code that only
# a reference lexicon with ICD9CM knows, and 999.99 is a code that no lexicon
# knows.
describe "the code check of a Database" do
  def not_present = ConceptQL::Operators::Vocabulary::NOT_PRESENT_IN_DATASET
  def unknown = ConceptQL::Operators::Operator::UNKNOWN_CODE
  def no_records = ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA

  # concepts: [vocabulary_id, code, name] rows. etl_vocabulary_ids: nil
  # leaves the table out.
  def lexicon_db(concepts, etl_vocabulary_ids: nil)
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
    concepts.each_with_index do |(vocabulary_id, code, name), i|
      db[:concept].insert(concept_id: i + 1, concept_code: code, concept_name: name, vocabulary_id: vocabulary_id)
    end
    concepts.map(&:first).uniq.each { |id| db[:vocabulary].insert(vocabulary_id: id, vocabulary_name: id) }
    # The gdm data model checks the data only when both tables exist.
    db.create_table(:patients) { Integer :id }
    db.create_table(:clinical_codes) do
      Integer :id
      Integer :clinical_code_concept_id
      String :clinical_code_vocabulary_id
    end
    if etl_vocabulary_ids
      db.create_table(:etl_vocabulary_ids) { String :vocabulary_id }
      etl_vocabulary_ids.each { |id| db[:etl_vocabulary_ids].insert(vocabulary_id: id) }
    end
    db
  end

  # A dataset lexicon with or without ICD9CM. It always has CPT4, so it is
  # never empty.
  def dataset(has_icd9:, **opts)
    concepts = [ %w[CPT4 99214 Office] ]
    concepts << [ "ICD9CM", "412", "Old myocardial infarction" ] if has_icd9
    lexicon_db(concepts, **opts)
  end

  # A reference lexicon with or without ICD9CM.
  def reference(has_icd9:)
    concepts = [ %w[CPT4 99214 Office], %w[HCPCS J9999 Drug] ]
    concepts += [ [ "ICD9CM", "412", "Old myocardial infarction" ], %w[ICD9CM 250.00 Diabetes] ] if has_icd9
    ConceptQL::Lexicon.new(lexicon_db(concepts))
  end

  def database(data_db, reference_lexicon: nil)
    ConceptQL::Database.new(data_db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(data_db),
                                     reference_lexicon: reference_lexicon)
  end

  def warnings(cdb, statement)
    by_operator(cdb.query(statement).warnings)
  end

  describe "the five cases of the rule" do
    it "calls a code unknown when the dataset's lexicon has the vocabulary and there is no reference lexicon" do
      cdb = database(dataset(has_icd9: true))

      _(cdb.check_codes(cdb.db, "ICD9CM", %w[412 250.00 999.99])).must_equal [ [], %w[250.00 999.99] ]
      _(warnings(cdb, %w[icd9 412 250.00 999.99])).must_equal({ "icd9" => [ [ unknown, "250.00", "999.99" ] ] })
    end

    it "asks the reference lexicon when the dataset's lexicon has the vocabulary" do
      cdb = database(dataset(has_icd9: true), reference_lexicon: reference(has_icd9: true))

      _(cdb.check_codes(cdb.db, "ICD9CM", %w[412 250.00 999.99])).must_equal [ %w[250.00], %w[999.99] ]
      _(warnings(cdb, %w[icd9 412 250.00 999.99]))
        .must_equal({ "icd9" => [ [ not_present, "250.00" ], [ unknown, "999.99" ] ] })

      # A reference lexicon without the vocabulary knows none of the codes.
      cdb = database(dataset(has_icd9: true), reference_lexicon: reference(has_icd9: false))

      _(warnings(cdb, %w[icd9 412 250.00 999.99])).must_equal({ "icd9" => [ [ unknown, "250.00", "999.99" ] ] })
    end

    it "applies the 2020 rule when the dataset's lexicon lacks the vocabulary and there is no reference lexicon" do
      cdb = database(dataset(has_icd9: false))

      _(cdb.check_codes(cdb.db, "ICD9CM", %w[250.00 999.99])).must_equal [ [], [] ]
      _(warnings(cdb, %w[icd9 250.00 999.99])).must_equal({})
    end

    it "asks the reference lexicon when only the reference lexicon has the vocabulary" do
      cdb = database(dataset(has_icd9: false), reference_lexicon: reference(has_icd9: true))

      _(cdb.check_codes(cdb.db, "ICD9CM", %w[250.00 999.99])).must_equal [ %w[250.00], %w[999.99] ]
      _(warnings(cdb, %w[icd9 250.00 999.99])).must_equal({ "icd9" => [ [ not_present, "250.00" ], [ unknown, "999.99" ] ] })
    end

    it "applies the 2020 rule when neither lexicon has the vocabulary" do
      cdb = database(dataset(has_icd9: false), reference_lexicon: reference(has_icd9: false))

      _(cdb.check_codes(cdb.db, "ICD9CM", %w[250.00 999.99])).must_equal [ [], [] ]
      _(warnings(cdb, %w[icd9 250.00 999.99])).must_equal({})
    end
  end

  describe "etl_vocabulary_ids" do
    it "does not change the 2020 rule" do
      [ %w[ICD9CM], %w[CPT4] ].each do |ids|
        cdb = database(dataset(has_icd9: false, etl_vocabulary_ids: ids))
        expected = ids.include?("ICD9CM") ? {} : { "icd9" => [ [ no_records ] ] }

        _(warnings(cdb, %w[icd9 250.00 999.99])).must_equal(expected, ids.inspect)
      end
    end

    it "does not change the result without the 2020 rule" do
      cdb = database(dataset(has_icd9: true, etl_vocabulary_ids: %w[ICD9CM]), reference_lexicon: reference(has_icd9: true))

      _(warnings(cdb, %w[icd9 412 250.00 999.99]))
        .must_equal({ "icd9" => [ [ not_present, "250.00" ], [ unknown, "999.99" ] ] })
    end
  end

  # With no records of the vocabulary in the data, the no-records warning
  # already says that every code is absent. So only the not-present warning
  # is not given: a typo is still an unknown code, and a reused code still
  # gets its warning.
  describe "with no records of the vocabulary in the data" do
    it "gives unknown codes and reused codes but no not-present warning" do
      data_db = lexicon_db([ [ "ICD9CM", "412", "Old myocardial infarction" ], [ "ICD9CM", "412", "Another name" ],
                             %w[CPT4 99214 Office] ], etl_vocabulary_ids: %w[CPT4])
      cdb = database(data_db, reference_lexicon: reference(has_icd9: true))

      _(cdb.check_codes(data_db, "ICD9CM", %w[412 250.00 999.99])).must_equal [ %w[250.00], %w[999.99] ]
      _(warnings(cdb, %w[icd9 412 250.00 999.99])).must_equal(
        { "icd9" => [ [ no_records ], [ unknown, "999.99" ],
                      [ "code(s) with more than one meaning", "412: Another name | Old myocardial infarction" ] ] }
      )
    end

    it "gives cpt_or_hcpcs unknown codes but no not-present warning" do
      cdb = database(dataset(has_icd9: true, etl_vocabulary_ids: %w[ICD9CM]), reference_lexicon: reference(has_icd9: false))

      _(cdb.check_codes(cdb.db, %w[CPT4 HCPCS], %w[99214 J9999 99999])).must_equal [ %w[J9999], %w[99999] ]
      _(warnings(cdb, %w[cpt_or_hcpcs 99214 J9999 99999])).must_equal(
        { "cpt_or_hcpcs" => [ [ no_records ], [ unknown, "99999" ] ] }
      )
    end
  end

  # cpt_or_hcpcs checks its codes as one set. The 2020 rule applies only
  # when no lexicon has a concept of any of its vocabularies.
  describe "cpt_or_hcpcs" do
    it "applies the 2020 rule only when no lexicon has any of its vocabularies" do
      cdb = database(lexicon_db([ %w[ICD9CM 412 Old] ]))

      _(warnings(cdb, %w[cpt_or_hcpcs 99999])).must_equal({})

      cdb = database(lexicon_db([ %w[ICD9CM 412 Old] ]), reference_lexicon: reference(has_icd9: false))

      _(warnings(cdb, %w[cpt_or_hcpcs 99214 J9999 99999]))
        .must_equal({ "cpt_or_hcpcs" => [ [ not_present, "99214", "J9999" ], [ unknown, "99999" ] ] })
    end

    it "knows a code that one vocabulary has, and calls the others unknown when another vocabulary has concepts" do
      cdb = database(dataset(has_icd9: false))

      _(warnings(cdb, %w[cpt_or_hcpcs 99214 J9999 99999])).must_equal({ "cpt_or_hcpcs" => [ [ unknown, "J9999", "99999" ] ] })
    end
  end

  # information_periods checks its codes of GDM_INFORMATION_TYPE through the
  # same rule.
  describe "information_periods" do
    let(:information_types) { lexicon_db([ %w[GDM_INFORMATION_TYPE PARTD Part_D] ]) }

    it "calls a code unknown when only the reference lexicon has the vocabulary" do
      cdb = database(dataset(has_icd9: true), reference_lexicon: ConceptQL::Lexicon.new(information_types))

      _(warnings(cdb, %w[information_periods PARTD PARTX]))
        .must_equal({ "information_periods" => [ [ not_present, "PARTD" ], [ unknown, "PARTX" ] ] })
    end

    it "applies the 2020 rule when no lexicon has the vocabulary" do
      _(warnings(database(dataset(has_icd9: true)), %w[information_periods PARTX])).must_equal({})
    end

    it "calls a code unknown when the dataset's lexicon has the vocabulary" do
      _(warnings(database(information_types), %w[information_periods PARTD PARTX]))
        .must_equal({ "information_periods" => [ [ unknown, "PARTX" ] ] })
    end
  end
end

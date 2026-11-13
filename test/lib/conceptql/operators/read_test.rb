# frozen_string_literal: true

require_relative "../../../helper"

# read is the vocabulary operator of the Read vocabulary, built from its row of
# config/vocabularies.csv (bead conceptql-qdn9). Before, it was an operator
# class that wrapped one Vocabulary operator, so it got no vocabulary check.
describe "the read operator" do
  let(:mock_cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  it "is a vocabulary operator of the Read vocabulary" do
    _(mock_cdb.operators["read"].ancestors).must_include ConceptQL::Operators::Vocabulary
    _(mock_cdb.operators["read"].entry.omopv5_id).must_equal "Read"
    _(ConceptQL::Operators.const_defined?(:Read, false)).must_equal false
  end

  it "should include measurement columns under GDM" do
    db = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    _(db.query(%w[read xyz]).operator.required_columns).must_include(:range_high)
  end

  # Union merges the vocabulary operators of one domain into one scan, and the
  # scan takes its columns from its first operator. read has the lab columns
  # and icd9 does not, so each gets its own scan.
  it "keeps the default column family of an icd9 in the same union" do
    sql = mock_cdb.query([ "union", %w[read 283Z.00], %w[icd9 412] ]).sql

    _(sql.scan(/CAST\('lab' AS \w+\) AS "column_family"/).length).must_equal 1
    _(sql.scan(/CAST\('default' AS \w+\) AS "column_family"/).length).must_equal 1
  end

  # A small sqlite database that is the OHDSI lexicon, and for the warnings
  # also the data database. ConceptQL builds no SQL for sqlite, so the SQL
  # comes from a mock Postgres data database with the same lexicon. The Read
  # vocabulary has two codes that differ only in case, as the real vocabulary
  # does, and S100z00, which it has only in lower case.
  describe "with a lexicon" do
    let(:read_name) { "NHS UK Read Codes Version 2 (HSCIC)" }

    let(:ldb) do
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
      db[:vocabulary].insert(vocabulary_id: "Read", vocabulary_name: read_name)
      db[:concept].import(%i[concept_id concept_code concept_name vocabulary_id],
                          [ [ 1, "13g4.00", "Born in Burkina Faso", "Read" ],
                            [ 2, "13G4.00", "Social worker involved", "Read" ],
                            [ 3, "S100z00", "Fracture of skull vault NOS", "Read" ] ])
      db
    end

    let(:cdb) { ConceptQL::Database.new(ldb, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(ldb)) }

    let(:sql_cdb) do
      ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm, lexicon: ConceptQL::Lexicon.new(ldb))
    end

    def warnings(statement)
      by_operator(cdb.query(statement).warnings).fetch("read", [])
    end

    def concept_ids_in(statement)
      sql_cdb.query(statement).sql[/"clinical_code_concept_id" IN \(([^)]*)\)/, 1]
    end

    it "warns about an unknown Read code" do
      _(warnings(%w[read XYS 13g4.00])).must_equal [ [ "unknown code(s)", "XYS" ] ]
    end

    it "matches a code only in its own case" do
      _(warnings(%w[read 13g4.00 13G4.00])).must_be_empty
      _(concept_ids_in(%w[read 13g4.00])).must_equal "1"
      _(concept_ids_in(%w[read 13G4.00])).must_equal "2"
    end

    it "does not match a code in the wrong case, and reports it as an unknown code" do
      _(warnings(%w[read S100Z00 S100z00])).must_equal [ [ "unknown code(s)", "S100Z00" ] ]
      _(concept_ids_in(%w[read S100Z00 S100z00])).must_equal "3"
      _(sql_cdb.query(%w[read S100Z00]).sql).wont_match(/"clinical_code_concept_id" IN \(\d/)
    end

    # The lexicon's vocabulary_name fills a blank of the CSV row, so the names
    # are compared with and without a lexicon.
    it "keeps the names and the description of read, with and without a lexicon" do
      [ mock_cdb, cdb ].each do |database|
        metadata = database.operators(:gdm).fetch("read").to_metadata("read")

        _(metadata.slice(:preferred_name, :short_name, :long_name, :desc, :predominant_domains, :spec_id))
          .must_equal({ preferred_name: "READ", short_name: "READ", long_name: read_name,
                        desc: "Selects results based on the Read vocabulary.",
                        predominant_domains: [ "condition_occurrence" ], spec_id: "vocabulary-operator" })
        _(metadata[:categories]).must_equal [ [ "Select by Clinical Codes" ] ]
        _(metadata[:arguments].map { |name, opts| [ name, opts[:label] ] }).must_equal [ [ :codes, "READ Codes" ] ]
      end
    end
  end
end

# frozen_string_literal: true

require "tmpdir"
require_relative "../../db_helper"

# A Database can hold a reference lexicon (the full lexicon) beside the
# lexicon of its dataset, which can be trimmed to the codes that the data
# contains (bead conceptql-8oim). Only the code checks read the reference
# lexicon: a code that only it knows is "not present in this dataset", and a
# code that neither knows is unknown. Both are warnings.
describe "ConceptQL::Database with a reference lexicon" do
  def not_present = ConceptQL::Operators::Vocabulary::NOT_PRESENT_IN_DATASET
  def unknown = ConceptQL::Operators::Operator::UNKNOWN_CODE
  def no_records = ConceptQL::Operators::Vocabulary::NO_RECORDS_IN_DATA

  let(:data_model) { CDB.opts[:data_model] }

  def warnings(cdb, statement)
    by_operator(ConceptQL::Annotation.new(cdb.query(statement).annotate).warnings)
  end

  def errors(cdb, statement)
    by_operator(ConceptQL::Annotation.new(cdb.query(statement).annotate).errors)
  end

  # Sets LEXICON_URL, with a fresh Database.lexicon_db, which is kept for the
  # life of the process. Both are restored afterwards.
  def with_lexicon_url(url)
    klass = ConceptQL::Database
    had_db = klass.instance_variable_defined?(:@lexicon_db)
    old_db = klass.instance_variable_get(:@lexicon_db)
    old_url = ENV.fetch("LEXICON_URL", nil)
    klass.remove_instance_variable(:@lexicon_db) if had_db
    ENV["LEXICON_URL"] = url
    yield
  ensure
    ENV["LEXICON_URL"] = old_url
    new_db = klass.instance_variable_get(:@lexicon_db) if klass.instance_variable_defined?(:@lexicon_db)
    new_db&.disconnect
    klass.remove_instance_variable(:@lexicon_db) if klass.instance_variable_defined?(:@lexicon_db)
    klass.instance_variable_set(:@lexicon_db, old_db) if had_db
  end

  # A SQLite database with the four OHDSI vocabulary tables and one ICD9CM
  # concept, 412.
  def write_sqlite_lexicon(path)
    db = Sequel.connect("sqlite://#{path}")
    db.create_table(:concept) do
      Integer :concept_id
      String :concept_code
      String :vocabulary_id
      String :concept_name
    end
    db.create_table(:concept_ancestor) do
      Integer :ancestor_concept_id
      Integer :descendant_concept_id
    end
    db.create_table(:concept_relationship) do
      Integer :concept_id_1
      Integer :concept_id_2
      String :relationship_id
    end
    db.create_table(:vocabulary) do
      String :vocabulary_id
      String :vocabulary_name
    end
    db[:concept].insert(concept_id: 1, concept_code: "412", vocabulary_id: "ICD9CM", concept_name: "Old MI")
    db[:vocabulary].insert(vocabulary_id: "ICD9CM", vocabulary_name: "ICD9CM")
  ensure
    db&.disconnect
  end

  describe "the option" do
    it "uses reference_lexicon: when it is given" do
      reference = ConceptQL::Lexicon.new(nil)

      _(ConceptQL::Database.new(nil, reference_lexicon: reference).reference_lexicon).must_be_same_as reference
    end

    it "uses the LEXICON_URL lexicon, with its own cache, when the option is not given" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "lexicon.sqlite")
        write_sqlite_lexicon(path)

        with_lexicon_url("sqlite://#{path}") do
          reference = ConceptQL::Database.new(nil, data_model: data_model).reference_lexicon

          _(reference.strategy).must_equal :ohdsi
          _(reference.cache).must_equal({})
          _(reference.known_codes(nil, "ICD9CM", %w[412 999], check_case: false)).must_equal %w[412]
        end
      end
    end

    it "has no reference lexicon when neither exists" do
      with_lexicon_url(nil) do
        _(ConceptQL::Database.new(nil).reference_lexicon).must_be_nil
        _(ConceptQL::Database.new(DB, data_model: data_model).reference_lexicon).must_be_nil
      end
    end
  end

  # The DuckDB fixture's vocabulary tables are the full lexicon. The trimmed
  # one is a copy in a temporary DuckDB file of the ICD9CM concepts only,
  # without 300 of them. The fixture itself is not changed.
  describe "on the DuckDB fixture" do
    before do
      skip "needs the DuckDB fixture (just test-duckdb)" unless DB.database_type.to_sym == :duckdb

      @dir = Dir.mktmpdir
      @full = ConceptQL::Lexicon.for_dataset(DB)
      icd9 = DB[:concept].where(vocabulary_id: "ICD9CM")
      @not_present = icd9.order(:concept_code).select_map(:concept_code)
                         .grep(/\A\d{3}\.\d{2}\z/).first(300)
      tables = {
        concept: icd9.exclude(concept_code: @not_present),
        vocabulary: DB[:vocabulary].where(vocabulary_id: "ICD9CM"),
        concept_ancestor: DB[:concept_ancestor].where(false),
        concept_relationship: DB[:concept_relationship].where(false)
      }
      tables.each do |name, ds|
        DB.run("COPY (#{ds.sql}) TO #{DB.literal(File.join(@dir, "#{name}.parquet"))} (FORMAT parquet)")
      end
      @trimmed_db = Sequel.connect("duckdb://#{File.join(@dir, "trimmed.duckdb")}")
      tables.each_key do |name|
        @trimmed_db.run("CREATE TABLE #{name} AS SELECT * FROM read_parquet(#{@trimmed_db.literal(File.join(@dir, "#{name}.parquet"))})")
      end
      @trimmed = ConceptQL::Lexicon.new(nil, @trimmed_db, strategy: ConceptQL::LexiconOhdsi.new(@trimmed_db), cache: true)
    end

    after do
      @trimmed_db&.disconnect
      FileUtils.rm_rf(@dir) if @dir
    end

    def dataset_only(data_db = DB)
      ConceptQL::Database.new(data_db, data_model: data_model, lexicon: @trimmed)
    end

    def with_reference(data_db = DB)
      ConceptQL::Database.new(data_db, data_model: data_model, lexicon: @trimmed, reference_lexicon: @full)
    end

    it "keeps the premises: 300 codes are only in the full lexicon, and 412 and 000.00 are as named" do
      _(@not_present.size).must_equal 300
      _(@trimmed.known_codes(DB, "ICD9CM", @not_present, check_case: false)).must_equal []
      _(@full.known_codes(DB, "ICD9CM", @not_present, check_case: false).sort).must_equal @not_present
      _(@trimmed.known_codes(DB, "ICD9CM", %w[412 000.00], check_case: false)).must_equal %w[412]
      _(@full.known_codes(DB, "ICD9CM", %w[000.00], check_case: false)).must_equal []
    end

    it "warns that a code of the full lexicon only is not present, and that a code of neither is unknown" do
      code = @not_present.first

      _(warnings(with_reference, [ "icd9", code, "000.00", "412" ]))
        .must_equal({ "icd9" => [ [ not_present, code ], [ unknown, "000.00" ] ] })
    end

    it "gives no warning for a code that both lexicons know" do
      _(warnings(with_reference, %w[icd9 412])).must_equal({})
    end

    it "lists every code that is not present" do
      _(warnings(with_reference, [ "icd9", *@not_present ])).must_equal({ "icd9" => [ [ not_present, *@not_present ] ] })
    end

    it "calls the codes unknown without a reference lexicon, as before" do
      code = @not_present.first

      _(warnings(dataset_only, [ "icd9", code, "000.00", "412" ])).must_equal({ "icd9" => [ [ unknown, code, "000.00" ] ] })
    end

    it "makes the same SQL and the same counts with and without the reference lexicon" do
      statement = [ "union", [ "icd9", "412", *@not_present.first(5) ], %w[cpt 99213] ]

      # A CTE name ends in a random hex string.
      sql = ->(cdb) { cdb.query(statement).sql.gsub(/_\d+_\d+_\h{32}/, "_CTE") }

      _(sql.call(with_reference)).must_equal sql.call(dataset_only)
      _(with_reference.query(statement).query.count).must_equal dataset_only.query(statement).query.count
      _(with_reference.query(statement).query.count).must_be :>, 0
    end

    # The trimmed lexicon has no CPT4 concepts. CPT4 is in etl_vocabulary_ids,
    # so the no-records warning does not fire for cpt.
    describe "the 2020 empty-vocabulary rule" do
      it "does not accept every code of an empty vocabulary with a reference lexicon" do
        _(warnings(with_reference, %w[cpt 99213 00000])).must_equal({ "cpt" => [ [ not_present, "99213" ], [ unknown, "00000" ] ] })
        _(warnings(with_reference(nil), %w[cpt 99213])).must_equal({ "cpt" => [ [ not_present, "99213" ] ] })
      end

      it "does not accept every code of an empty vocabulary with a filled etl_vocabulary_ids" do
        _(DB[:etl_vocabulary_ids].count).must_be :>, 0
        _(warnings(dataset_only, %w[cpt 99213])).must_equal({ "cpt" => [ [ unknown, "99213" ] ] })
      end

      it "still accepts every code of an empty vocabulary with neither" do
        _(@trimmed_db.table_exists?(:etl_vocabulary_ids)).must_equal false
        [ nil, @trimmed_db ].each do |data_db|
          _(warnings(dataset_only(data_db), %w[cpt 99213])).must_equal({}, data_db.inspect)
        end
      end
    end

    it "calls a code not present when one vocabulary of a multiple-vocabulary operator knows it" do
      _(warnings(with_reference, %w[cpt_or_hcpcs 99213])).must_equal({ "cpt_or_hcpcs" => [ [ not_present, "99213" ] ] })
    end

    # ICD10CM is not in the fixture's etl_vocabulary_ids. I21.9 is only in the
    # full lexicon, and Z99.999 is in neither.
    it "gives an operator of a vocabulary that the data lacks only the no-records warning" do
      _(@full.known_codes(DB, "ICD10CM", %w[I21.9 Z99.999], check_case: false)).must_equal %w[I21.9]

      _(warnings(with_reference, %w[icd10cm I21.9 Z99.999])).must_equal({ "icd10cm" => [ [ no_records ] ] })
      _(warnings(dataset_only, %w[icd10cm I21.9 Z99.999])).must_equal({ "icd10cm" => [ [ no_records ] ] })
    end

    it "builds the operators of a vocabulary that only the reference lexicon has" do
      csv_ids = CSV.foreach(ConceptQL.vocabularies_file_path, headers: true, header_converters: :symbol)
                   .map { |row| ConceptQL::Vocabularies::Entry.new(row.to_hash.compact).id }
      full_only = @full.vocabularies.map { |row| ConceptQL::Vocabularies::Entry.new(row.compact).id } -
                  csv_ids - ConceptQL::Operators.static_operators.fetch(data_model).keys
      _(full_only).wont_be_empty
      name = full_only.first

      _(errors(dataset_only, [ name, "X" ])).must_equal({ name => [ [ "invalid operator", name ] ] })
      _(errors(with_reference, [ name, "X" ])).must_equal({})
    end
  end
end

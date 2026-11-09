# frozen_string_literal: true

require_relative "../../../helper"
require "date"

# A DRG code can have two meanings: its CMS-DRG meaning before the
# 2007-10-01 MS-DRG renumbering and its MS-DRG meaning after it. Event rows do
# not record which meaning applied, so Ryan ruled (seed conceptql-7p3,
# 2026-10-30) that a statement names the DRG system: ms_drg selects the DRG
# events from 2007-10-01, and cms_drg selects the DRG events before that day.
# drg is deprecated (bead conceptql-alw). The test fixtures hold DRG events
# from 2008 to 2010 only, so these tests check the generated SQL on a mock.
describe "the ms_drg and cms_drg operators" do
  let(:cutover) { ConceptQL::Vocabularies::DrgSystems::MS_DRG_START_DATE }

  def cdb(data_model = :gdm, host: :postgres, lexicon: nil)
    opts = { data_model: data_model }
    opts[:lexicon] = lexicon if lexicon
    ConceptQL::Database.new(Sequel.mock(host: host), **opts)
  end

  def where_clause(sql)
    sql.scan(/WHERE \((.*?)\)\) AS/).flatten
  end

  def warnings_for(statement, database = cdb)
    database.query(statement).scope_annotate(skip_counts: true)[:warnings]
  end

  it "names the first day of MS-DRG in one constant" do
    _(cutover).must_equal Date.new(2007, 10, 1)
  end

  %i[gdm gdm_wide].each do |data_model|
    describe "on #{data_model}" do
      let(:table) { data_model == :gdm ? "clinical_codes" : "observations" }

      it "selects DRG events from the cutover day with ms_drg" do
        sql = cdb(data_model).query(%w[ms_drg 001]).sql

        _(sql).must_include %{FROM "#{table}" WHERE (("clinical_code_vocabulary_id" = 'DRG') AND }
        _(sql).must_include %(AND ("start_date" >= '2007-10-01'))
        _(sql).wont_include %("start_date" < )
      end

      it "selects DRG events before the cutover day with cms_drg" do
        sql = cdb(data_model).query(%w[cms_drg 001]).sql

        _(sql).must_include %{FROM "#{table}" WHERE (("clinical_code_vocabulary_id" = 'DRG') AND }
        _(sql).must_include %(AND ("start_date" < '2007-10-01'))
        _(sql).wont_include %("start_date" >= )
      end

      it "keeps the date condition when it selects every code" do
        _(cdb(data_model).query([ "ms_drg", "*" ]).sql).must_include %(("start_date" >= '2007-10-01'))
        _(cdb(data_model).query([ "cms_drg", "*" ]).sql).must_include %(("start_date" < '2007-10-01'))
      end

      it "has no date condition with the deprecated drg" do
        _(cdb(data_model).query(%w[drg 001]).sql).wont_include %("start_date" >= )
        _(cdb(data_model).query(%w[drg 001]).sql).wont_include %("start_date" < )
      end
    end
  end

  it "keeps each operator's date condition when union merges them" do
    sql = cdb.query([ "union", %w[ms_drg 001], %w[cms_drg 002], %w[icd9 412] ]).sql

    _(sql).must_include %("clinical_code_vocabulary_id" IN ('DRG'))
    _(sql).must_include %(("start_date" >= '2007-10-01'))
    _(sql).must_include %(("start_date" < '2007-10-01'))
  end

  it "writes the same date condition for DuckDB and Spark" do
    %i[duckdb spark].each do |database_type|
      _(cdb.query(%w[ms_drg 001], database_type: database_type).sql).must_include %(("start_date" >= '2007-10-01'))
      _(cdb.query(%w[cms_drg 001], database_type: database_type).sql).must_include %(("start_date" < '2007-10-01'))
    end
  end

  it "checks codes against the DRG format of vocabulary_formats" do
    %w[ms_drg cms_drg].each do |name|
      operator = cdb.query([ name, "001", "1", "0001" ]).operator
      _(cdb.query([ name, "001" ]).sql).must_include %("clinical_code_vocabulary_id" = 'DRG')
      _(operator.vocab_entry.format_regexp).must_equal ConceptQL::Vocabularies::Formats.pattern("DRG")
      _(warnings_for([ name, "001" ]).to_h).must_be_empty
      # A malformed code is a warning (seeds conceptql-0eb and conceptql-ysx, ruled 2026-10-30).
      _(cdb.query([ name, "001", "1", "0001" ]).validation_errors).must_equal({})
      _(warnings_for([ name, "001", "1", "0001" ])).must_equal({ name => [ [ "improperly formatted code", "1", "0001" ] ] })
    end
  end

  describe "in the operator metadata" do
    let(:operators) { ConceptQL.metadata(cdb)[:operators] }

    it "lists ms_drg and cms_drg in the category of drg" do
      %w[ms_drg cms_drg].each do |name|
        _(operators.fetch(name)[:categories]).must_equal operators.fetch("drg")[:categories]
        _(operators.fetch(name)[:basic_type]).must_equal :selection
        _(operators.fetch(name)[:predominant_domains]).must_equal operators.fetch("drg")[:predominant_domains]
        _(operators.fetch(name)[:deprecated]).must_be_nil
      end
    end

    it "names each operator after its DRG system" do
      _(operators.fetch("ms_drg")[:preferred_name]).must_equal "MS-DRG"
      _(operators.fetch("cms_drg")[:preferred_name]).must_equal "CMS-DRG"
      codes_meaning = ConceptQL::Operators::Vocabulary.argument_options(:codes)[:meaning]
      _(operators.fetch("ms_drg")[:arguments]).must_equal [ [ :codes, { type: :codelist, meaning: codes_meaning, label: "MS-DRG Codes" } ] ]
      _(operators.fetch("ms_drg")[:short_name]).must_equal "MS-DRG"
      _(operators.fetch("cms_drg")[:short_name]).must_equal "CMS-DRG"
    end

    it "says drg is deprecated" do
      _(operators.fetch("drg")[:deprecated]).must_equal true
    end
  end

  describe "the deprecated drg" do
    let(:deprecation) do
      [
        "deprecated operator",
        "drg will become an error in a later release. A DRG code can have two meanings, and drg " \
        "selects the events of both. Use ms_drg for the MS-DRG meaning (events from 2007-10-01) or " \
        "cms_drg for the CMS-DRG meaning (events before 2007-10-01)."
      ]
    end

    it "warns on a drg statement" do
      _(warnings_for(%w[drg 001])).must_equal({ "drg" => [ deprecation ] })
    end

    it "still runs" do
      _(cdb.query(%w[drg 001]).sql).must_include %("clinical_code_vocabulary_id" = 'DRG')
    end

    it "gives no deprecation warning for ms_drg or cms_drg" do
      _(warnings_for([ "union", %w[ms_drg 001], %w[cms_drg 001] ]).to_h).must_be_empty
    end
  end

  # The OHDSI vocabulary keeps each meaning of a DRG code as its own concept
  # row, with concept_class_id MS-DRG for the MS-DRG meaning and DRG for the
  # CMS-DRG meaning. The GDM vocabulary keeps no class.
  describe "with a small lexicon" do
    def ohdsi_lexicon_db(with_class: true)
      Sequel.connect("sqlite:/").tap do |db|
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
          String :concept_class_id if with_class
        end
        db[:vocabulary].insert(vocabulary_id: "DRG", vocabulary_name: "DRG")
        [
          [ 1, "410", "Chemotherapy", "DRG" ],
          [ 2, "410", "Biliary tract", "MS-DRG" ],
          [ 3, "492", "Chemotherapy W/ Acute Leukemia", "DRG" ],
          [ 4, "492", "Chemotherapy W/ Acute Leukemia or High-Dose", "DRG" ],
          [ 5, "492", "Lower extrem", "MS-DRG" ],
          [ 6, "520", "Back and neck proc", "MS-DRG" ],
          [ 7, "015", "Old only", "DRG" ]
        ].each do |id, code, name, klass|
          row = { concept_id: id, concept_code: code, concept_name: name, vocabulary_id: "DRG" }
          row[:concept_class_id] = klass if with_class
          db[:concept].insert(row)
        end
      end
    end

    # Validation looks a code up only with a data database that is not a
    # mock and has the gdm data tables, so the lexicon database is the data
    # database too. The data tables stay empty.
    def live_cdb(lexicon_db)
      lexicon_db.create_table(:patients) { Integer :id }
      lexicon_db.create_table(:clinical_codes) { Integer :id }
      ConceptQL::Database.new(lexicon_db, data_model: :gdm, lexicon: ConceptQL::Lexicon.new(lexicon_db))
    end

    def code_list(statement, lexicon_db)
      cdb(lexicon: ConceptQL::Lexicon.new(lexicon_db)).query(statement).code_list.map(&:to_s)
    end

    it "names each code by the meaning of the operator's system" do
      ldb = ohdsi_lexicon_db

      _(code_list(%w[ms_drg 410 492], ldb)).must_equal [ "MS-DRG 410: Biliary tract", "MS-DRG 492: Lower extrem" ]
      _(code_list(%w[cms_drg 410 492], ldb)).must_equal [
        "CMS-DRG 410: Chemotherapy",
        "CMS-DRG 492: Chemotherapy W/ Acute Leukemia",
        "CMS-DRG 492: Chemotherapy W/ Acute Leukemia or High-Dose"
      ]
    end

    it "falls back to every name of a code that has no row of the system" do
      ldb = ohdsi_lexicon_db

      _(code_list(%w[cms_drg 520 410 999], ldb)).must_equal [
        "CMS-DRG 410: Chemotherapy",
        "CMS-DRG 520: Back and neck proc",
        "CMS-DRG 999"
      ]
      _(code_list(%w[ms_drg 015], ldb)).must_equal [ "MS-DRG 015: Old only" ]
    end

    it "falls back to every name when the concept table has no class" do
      ldb = ohdsi_lexicon_db(with_class: false)

      _(code_list(%w[ms_drg 410], ldb)).must_equal [ "MS-DRG 410: Chemotherapy", "MS-DRG 410: Biliary tract" ]
    end

    it "warns about reused codes for drg but not for ms_drg or cms_drg" do
      database = live_cdb(ohdsi_lexicon_db)

      _(warnings_for(%w[drg 410], database)["drg"]).must_include [
        "code(s) with more than one meaning", "410: Biliary tract | Chemotherapy"
      ]
      _(warnings_for(%w[ms_drg 410 492], database).to_h).must_be_empty
      _(warnings_for(%w[cms_drg 410 492], database).to_h).must_be_empty
    end

    it "warns about a code the DRG vocabulary does not know" do
      database = live_cdb(ohdsi_lexicon_db)

      _(warnings_for(%w[ms_drg 410 999], database)).must_equal({ "ms_drg" => [ [ "unknown code(s)", "999" ] ] })
    end
  end
end

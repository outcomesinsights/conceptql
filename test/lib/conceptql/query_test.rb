# frozen_string_literal: true

require_relative "../../db_helper"
require "climate_control"

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    _(CDB.query(
      [ :foo ]
    ).annotate).must_equal(
      [ "foo",
       { annotation: { counts: { invalid: { rows: 0, n: 0 } }, errors: [ [ "invalid operator", "foo" ] ] },
         name: "Invalid" } ]
    )
  end

  it "should handle query_cols for non-CDM tables" do
    _(CDB.query(
      [ :from, "other_table" ]
    ).query_cols).must_equal(ConceptQL::Scope::DEFAULT_COLUMNS.keys)
  end

  it "should not alter the Database instance when called" do
    og_opts = CDB.opts.dup
    _(CDB.query(
      [ :from, "other_table" ], scope_opts: { window_opts: { window_table: :some_table } }
    ).query_cols)
    _(CDB.opts).must_equal(og_opts)
  end

  # Before conceptql-fy3 this test called criteria_ids, which no file
  # defines, so must_raise caught the NoMethodError and the test passed for any
  # statement. The ICD-9 code was "203.0x", a second error, so the recall was
  # not the only reason to raise. Now the unknown label is the only error.
  it "should raise error if attempting to execute invalid recall" do
    statement = [ "after",
                  { left: [ "during",
                            { left: [ "occurrence", 4, [ "icd9", "203.00", { "label" => "Meyloma Dx" } ] ],
                              right: [ "time_window", [ "first", [ "recall", "Meyloma Dx" ] ],
                                       { "start" => "0", "end" => "90d" } ] } ],
                    right: [ "union",
                             [ "during",
                               { left: [ "time_window", [ "recall", "Qualifying Meyloma Dx" ], { "start" => "-90d", "end" => "0", "label" => "Meyloma 90-day Lookback" } ],
                                 right: [ "cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275",
                                          "88291", "88305", { "label" => "Bone Marrow" } ] } ],
                             [ "occurrence", 2, [ "during",
                                                  { left: [ "cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", { "label" => "Other Tests" } ],
                                                    right: [ "recall", "Meyloma 90-day Lookback" ] } ] ] ] } ]

    error = _ { CDB.query(statement).all }.must_raise(ConceptQL::InvalidStatementError)
    _(error.errors).must_equal("recall" => [ [ "no matching label", "Qualifying Meyloma Dx" ] ])
  end

  # conceptql-g2v: the plain query validates the statement first. Each of
  # these statements comes from jde's survey of production algorithms. Before,
  # the first one crashed with NoMethodError, the second one silently ignored
  # the keyword and returned no rows, and the third one raised RuntimeError.
  describe "building the SQL of an invalid statement" do
    {
      "provider_filter without roles" => [
        [ "provider_filter", [ "icd9", "412" ], { "specialties" => "*" } ],
        { "provider_filter" => [ [ "required option not present", "roles" ] ] },
        "provider_filter: required option not present (roles)"
      ],
      "provenance with an unknown keyword" => [
        [ "provenance", [ "icd9", "412" ], "inpatient:primary_or_first" ],
        { "provenance" => [ [ "unrecognized keywords", "inpatient:primary_or_first" ] ] },
        "provenance: unrecognized keywords (inpatient:primary_or_first)"
      ],
      "provenance with a concept ID" => [
        [ "provenance", [ "icd9", "412" ], "38000204" ],
        { "provenance" => [ [ "unrecognized keywords", "38000204" ] ] },
        "provenance: unrecognized keywords (38000204)"
      ],
      "an unknown operator" => [
        [ "union", [ "usrds_first_transplant" ], [ "icd9", "412" ] ],
        { "usrds_first_transplant" => [ [ "invalid operator", "usrds_first_transplant" ] ] },
        "usrds_first_transplant: invalid operator (usrds_first_transplant)"
      ],
      # conceptql-e7y: the JDE algorithm clia_lab_use has the statement [].
      # Before, every method crashed with ArgumentError in Nodifier#create.
      "an empty statement" => [
        [],
        { "invalid" => [ [ "empty statement" ] ] },
        "invalid: empty statement"
      ],
      "an empty operand" => [
        [ "union", [], [ "icd9", "412" ] ],
        { "invalid" => [ [ "empty statement" ] ] },
        "invalid: empty statement"
      ]
    }.each do |name, (statement, errors, line)|
      { sql: ->(q) { q.sql }, query: ->(q) { q.query }, sql_statements: ->(q) { q.sql_statements(:create_tables) },
        all: ->(q) { q.all } }.each do |meth, call|
        it "raises InvalidStatementError from ##{meth} for #{name}" do
          error = _ { call.(CDB.query(statement)) }.must_raise(ConceptQL::InvalidStatementError)
          _(error.errors).must_equal(errors)
          _(error.statement).must_equal(CDB.query(statement).statement)
          _(error.message).must_include("Invalid ConceptQL statement")
          _(error.message).must_include("  #{line}")
          _(error.cause).must_be_nil
        end
      end

      it "raises InvalidStatementError for #{name} inside a window" do
        window = [ "window", statement, { "start_date" => "1900-01-01", "end_date" => "2100-12-31" } ]
        error = _ { CDB.query(window).sql }.must_raise(ConceptQL::InvalidStatementError)
        _(error.errors).must_equal(errors)
      end

      it "does not change what annotate returns for #{name}" do
        query = CDB.query(statement)
        _ { query.sql }.must_raise(ConceptQL::InvalidStatementError)
        _(query.annotate).must_equal(CDB.query(statement).annotate)
      end
    end

    # conceptql-e7y: t_shank and jde validate stored statements, so an empty
    # one must be reported, not raise. [[]] unwraps to [].
    [ [], [ [] ], [ "union", [], [ "icd9", "412" ] ] ].each do |statement|
      it "reports #{statement.inspect} as an empty statement from #validation_errors" do
        _(CDB.query(statement).validation_errors).must_equal("invalid" => [ [ "empty statement" ] ])
      end
    end

    it "reports an empty statement without a database" do
      cdb = ConceptQL::Database.new(nil, data_model: :gdm)
      _(cdb.query([]).validation_errors).must_equal("invalid" => [ [ "empty statement" ] ])
      _ { cdb.query([]).sql }.must_raise(ConceptQL::InvalidStatementError)
    end

    it "reports an algorithm whose stored statement is empty" do
      query = CDB.query([ "algorithm", "clia_lab_use" ], algorithm_fetcher: ->(_alg) { [ [], "CLIA lab use" ] })
      _(query.validation_errors).must_equal("invalid" => [ [ "empty statement" ] ])
    end

    it "keeps the 0.4.0 names: a Query::QueryError, also named Query::InvalidStatementError" do
      _(ConceptQL::Query::InvalidStatementError).must_be_same_as(ConceptQL::InvalidStatementError)
      _(ConceptQL::InvalidStatementError.ancestors).must_include(ConceptQL::Query::QueryError)
    end

    it "builds the SQL of a valid statement" do
      _(CDB.query([ "icd9", "412" ]).sql).must_match(/SELECT/i)
    end

    {
      "the count deprecation" => [ "count", [ "icd9", "412" ] ],
      "an unknown code" => [ "icd9", "412", "000.00" ]
    }.each do |name, statement|
      it "builds the SQL of a statement whose only warning is #{name}" do
        annotation = CDB.query(statement).scope_annotate(skip_counts: true)
        _(annotation[:errors]).must_be_empty
        _(annotation[:warnings]).wont_be_empty
        _(CDB.query(statement).sql).must_match(/SELECT/i)
        _(CDB.query(statement).count).must_be_kind_of(Integer)
      end
    end
  end

  # conceptql-fy3: the window table's own statement is a second statement.
  # Annotate reports its errors under "window_table" and does not count, because
  # every count joins the window table. The plain query of the outer statement
  # raises with the same errors. Before, a counted annotate raised the window
  # table's InvalidStatementError, and annotate without counts reported nothing.
  describe "a window whose window table statement is invalid" do
    let(:statement) do
      [ "window", [ "icd9", "412" ],
        { "window_table" => [ "provider_filter", [ "icd9", "412" ], { "specialties" => "*" } ] } ]
    end
    let(:errors) do
      { "window_table" => [ [ "provider_filter: required option not present", "roles" ] ] }
    end

    it "reports the window table's errors from a counted scope_annotate" do
      _(CDB.query(statement).scope_annotate[:errors]).must_equal(errors)
    end

    it "reports the window table's errors from scope_annotate without counts" do
      _(CDB.query(statement).scope_annotate(skip_counts: true)[:errors]).must_equal(errors)
    end

    it "annotates with counts and does not count" do
      _(CDB.query(statement).annotate).must_equal(
        [ "icd9", "412", { annotation: { counts: { condition_occurrence: { rows: 0, n: 0 } } }, name: "ICD-9 CM" } ]
      )
    end

    it "raises InvalidStatementError for the outer statement from the plain query" do
      query = CDB.query(statement)
      error = _ { query.sql }.must_raise(ConceptQL::InvalidStatementError)
      _(error.errors).must_equal(errors)
      _(error.statement).must_equal(query.statement)
      _(error.message).must_include("  window_table: provider_filter: required option not present (roles)")
    end

    it "reports the errors of a window table inside a window table" do
      nested = [ "window", [ "icd9", "412" ], { "window_table" => statement } ]
      _(CDB.query(nested).scope_annotate[:errors]).must_equal(
        "window_table" => [ [ "window_table: provider_filter: required option not present", "roles" ] ]
      )
    end
  end

  describe "#code_list" do
    it "should handle nil for a DB" do
      ClimateControl.modify(LEXICON_URL: nil) do
        db = ConceptQL::Database.new(nil)
        query = db.query([ "union", %w[cpt 80230], [ "icd9", "250.00", "250.02" ] ])
        expected = [
          "CPT 80230",
          "ICD-9 CM 250.00",
          "ICD-9 CM 250.02"
        ]
        _(query.code_list.map(&:to_s)).must_equal(expected)
      end
    end

    it "should handle nil for preferred name" do
      db = ConceptQL::Database.new(DB)
      query = db.query(%w[revenue_code 0100])
      _(query.code_list.map(&:to_s)).must_equal([
                                                  "Revenue Code 0100: All-Inclusive Room and Board Plus Ancillary"
                                                ])
    end

    # Before conceptql-brm this test was "should return codes even if
    # database search_path is bad": a real database with no vocabulary fell
    # back to LexiconNoDB without a word, and code_list listed the codes. Seed
    # conceptql-ysx ruled (option A) that such a Database raises, and code
    # lists are not exempt.
    it "raises NoVocabularyError, before any code list, when the database search_path is bad" do
      ClimateControl.modify(LEXICON_URL: nil) do
        seq_db = Sequel.connect(DB.opts.except(:after_connect).merge(search_path: "bad_path"))
        _ { ConceptQL::Database.new(seq_db) }.must_raise ConceptQL::Lexicon::NoVocabularyError
      ensure
        seq_db&.disconnect
      end
    end

    # Before conceptql-brm this test read a second connection with the search
    # path "bad_path". Postgres's after_connect restored the real search path,
    # but on DuckDB that connection had no vocabulary and now raises
    # NoVocabularyError. A "*" needs no vocabulary, so the suite's own
    # Database serves.
    it "should return asterisk when selecting all" do
      query = CDB.query([ "union", [ "cpt", "*" ], [ "icd9", "250.00", "*" ] ])
      _(query.code_list(DB).map(&:to_s)).must_equal([
                                                      "CPT *: ALL CODES",
                                                      "ICD-9 CM *: ALL CODES"
                                                    ])
    end

    it "should return codes from vocabulary-based operators even with no db" do
      ClimateControl.modify(LEXICON_URL: nil) do
        db = ConceptQL::Database.new(nil)
        query = db.query([ "union", %w[cpt_or_hcpcs 80230], [ "ATC", "*" ] ])
        _(query.code_list(nil).map(&:to_s)).must_equal([
                                                         "CPT or HCPCS 80230",
                                                         "WHO ATC *: ALL CODES"
                                                       ])
      end
    end

    it "should return codes even if the code doesn't exist in the database" do
      query = CDB.query(%w[hcpcs A0000 A0021])
      _(query.code_list.map(&:code).sort).must_equal(%w[A0000 A0021])
    end

    # These statements are invalid on purpose. Before conceptql-9gc, code_list
    # raised NoMethodError on a missing operand of each one.
    {
      "after/anno_1.json" => "after: wrong option format (left, 412)",
      "after/anno_2.json" => "after: required option not present (left)",
      "after/anno_3.json" => "after: required option not present (right)",
      "recall/anno_1.json" => "recall: no matching label (Heart Attack)",
      "recall/anno_3.json" => "recall: no matching label (HA1)",
      "recall/anno_4.json" => "recall: has no arguments",
      "recall/anno_5.json" => "recall: has multiple arguments (foo, bar)",
      "recall/anno_6.json" => "recall: no matching label (Qualifying Meyloma Dx)",
      # A malformed code is an error (seed conceptql-0eb).
      "icd9/anno_invalid_code.json" => "icd9: improperly formatted code (XYS)"
    }.each do |file, expected_error|
      it "should raise InvalidStatementError naming the errors for #{file}" do
        statement = JSON.parse(File.read("test/statements/#{file}"))
        error = _ { CDB.query(statement).code_list }.must_raise(ConceptQL::Query::InvalidStatementError)
        _(error).must_be_kind_of(ConceptQL::Query::QueryError)
        _(error.message).must_include("Invalid ConceptQL statement")
        _(error.message).must_include(expected_error)
        _(error.errors).wont_be_empty
      end
    end

    it "should raise on a statement with errors even when its operator tree has every operand" do
      error = _ { CDB.query([ "count", [ "icd9", "412" ], [ "icd9", "250.00" ] ]).code_list }
              .must_raise(ConceptQL::Query::InvalidStatementError)
      _(error.message).must_include("count: has multiple upstreams (icd9, icd9)")
    end

    # 000.00 is a well-formed ICD-9 code that the vocabulary does not know, so
    # it is only a warning. A malformed code is an error (seed conceptql-0eb).
    it "should not raise on a statement with only warnings" do
      query = CDB.query(%w[icd9 412 000.00])
      _(query.scope_annotate(skip_counts: true)[:warnings]).wont_be_empty
      _(query.code_list.map(&:code)).must_equal(%w[412 000.00])
    end

    it "should not change what a later annotate returns" do
      statement = [ "union", %w[icd9 412 000.00], %w[cpt 99214] ]
      query = CDB.query(statement)
      query.code_list
      _(query.annotate).must_equal(CDB.query(statement).annotate)
    end
  end
end

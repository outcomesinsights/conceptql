# frozen_string_literal: true

require_relative "../../db_helper"
require "climate_control"

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    _(CDB.query(
      [ :foo ]
    ).annotate).must_equal(
      [ "foo",
       { annotation: { id: "foo-1", counts: { invalid: { rows: 0, n: 0 } }, errors: [ [ "invalid operator", "foo" ] ] },
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
    _(by_operator(error.errors)).must_equal({ "recall" => [ [ "no matching label", "Qualifying Meyloma Dx" ] ] })
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
      # The survey also had provenance with an unknown keyword. Bead
      # conceptql-amuu made that a warning, so the statement is valid.
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
          _(by_operator(error.errors)).must_equal(errors)
          _(error.statement).must_equal(CDB.query(statement).statement)
          _(error.message).must_include("Invalid ConceptQL statement")
          _(error.message).must_include("  #{line}")
          _(error.cause).must_be_nil
        end
      end

      it "raises InvalidStatementError for #{name} inside a window" do
        window = [ "window", statement, { "start_date" => "1900-01-01", "end_date" => "2100-12-31" } ]
        error = _ { CDB.query(window).sql }.must_raise(ConceptQL::InvalidStatementError)
        _(by_operator(error.errors)).must_equal(errors)
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
        _(by_operator(CDB.query(statement).validation_errors)).must_equal({ "invalid" => [ [ "empty statement" ] ] })
      end
    end

    it "reports an empty statement without a database" do
      cdb = ConceptQL::Database.new(nil, data_model: :gdm)
      _(by_operator(cdb.query([]).validation_errors)).must_equal({ "invalid" => [ [ "empty statement" ] ] })
      _ { cdb.query([]).sql }.must_raise(ConceptQL::InvalidStatementError)
    end

    it "reports an algorithm whose stored statement is empty" do
      query = CDB.query([ "algorithm", "clia_lab_use" ], algorithm_fetcher: ->(_alg) { [ [], "CLIA lab use" ] })
      _(by_operator(query.validation_errors)).must_equal({ "invalid" => [ [ "empty statement" ] ] })
    end

    # conceptql-si8t: #errors is a list, so two operators with the same name
    # keep their own errors. Before, the errors hash was keyed by the operator
    # name, and the second union replaced the first.
    it "lists every error of two operators with the same name" do
      statement = [ "union", [ "union" ], [ "union" ] ]
      error = _ { CDB.query(statement).sql }.must_raise(ConceptQL::InvalidStatementError)
      _(error.errors).must_equal [
        { operator: "union", id: "union-2", message: "has no upstream", details: [] },
        { operator: "union", id: "union-3", message: "has no upstream", details: [] }
      ]
      _(error.message.lines.grep(/\A  union: has no upstream\n\z/).size).must_equal 2
      _(CDB.query(statement).validation_errors).must_equal(error.errors)
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
      "an unknown code" => [ "icd9", "412", "000.00" ],
      # A malformed code is a warning (seeds conceptql-0eb and conceptql-ysx,
      # ruled 2026-10-30). The NDC format accepts only the 11-digit form.
      "a malformed code" => [ "icd9", "412", "410*" ],
      "a 9-digit NDC code" => [ "ndc", "003630641" ]
    }.each do |name, statement|
      it "builds the SQL of a statement whose only warning is #{name}" do
        query = CDB.query(statement)
        _(query.errors).must_be_empty
        _(query.warnings).wont_be_empty
        _(CDB.query(statement).sql).must_match(/SELECT/i)
        _(CDB.query(statement).count).must_be_kind_of(Integer)
      end
    end
  end

  # conceptql-fy3: the window table's own statement is a second statement.
  # Annotate keeps the window operator at the top and annotates the window
  # table's statement in place, in the window_table option, so each error
  # stays on the operator that has it (conceptql-si8t, option B, ruled
  # 2026-11-10). It does not count the outer statement, because every count
  # joins the window table. The plain query of the outer statement raises
  # with the same errors. Before conceptql-fy3, a counted annotate raised the
  # window table's InvalidStatementError, and annotate without counts reported
  # nothing. Until conceptql-si8t, only the scope hash (now removed) reported
  # the errors, under "window_table".
  describe "a window whose window table statement is invalid" do
    let(:statement) do
      [ "window", [ "icd9", "412" ],
        { "window_table" => [ "provider_filter", [ "icd9", "412" ], { "specialties" => "*" } ] } ]
    end
    let(:errors) do
      [ { operator: "provider_filter", id: "provider_filter-1", message: "required option not present",
          details: [ "roles" ] } ]
    end
    let(:no_rows) { { condition_occurrence: { rows: 0, n: 0 } } }

    it "reports the window table's errors from a counted annotate" do
      annotation = ConceptQL::Annotation.new(CDB.query(statement).annotate)
      _(annotation.errors).must_equal(errors)
      _(annotation.valid?).must_equal false
    end

    it "reports the window table's errors from annotate without counts" do
      query = CDB.query(statement)
      _(query.errors).must_equal(errors)
      _(query.valid?).must_equal false
      _(query.validation_errors).must_equal(errors)
    end

    it "annotates with counts, keeps the window at the top, and does not count" do
      _(CDB.query(statement).annotate).must_equal(
        [ "window",
          [ "icd9", "412", { annotation: { id: "icd9-1", counts: no_rows }, name: "ICD-9 CM" } ],
          { window_table: [ "provider_filter",
                            [ "icd9", "412", { annotation: { id: "icd9-2", counts: no_rows }, name: "ICD-9 CM" } ],
                            { specialties: "*",
                              annotation: { id: "provider_filter-1", counts: no_rows,
                                            errors: [ [ "required option not present", "roles" ] ] },
                              name: "Provider Filter" } ],
            annotation: { id: "window-1" } } ]
      )
    end

    it "prefixes each message of #window_table_errors with the operator name" do
      _(CDB.query(statement).send(:window_table_errors))
        .must_equal [ [ "provider_filter: required option not present", "roles" ] ]
    end

    it "raises InvalidStatementError for the outer statement from the plain query" do
      query = CDB.query(statement)
      error = _ { query.sql }.must_raise(ConceptQL::InvalidStatementError)
      _(error.errors).must_equal(errors)
      _(error.statement).must_equal(query.statement)
      _(error.message).must_include("  provider_filter: required option not present (roles)")
    end

    it "reports the errors of a window table inside a window table" do
      nested = [ "window", [ "icd9", "412" ], { "window_table" => statement } ]
      annotated = CDB.query(nested).annotate
      inner_window = annotated.last[:window_table]
      _(inner_window.first).must_equal "window"
      _(inner_window.last[:window_table].first).must_equal "provider_filter"
      _(ConceptQL::Annotation.new(annotated).errors).must_equal(errors)
      _ { CDB.query(nested).sql }.must_raise(ConceptQL::InvalidStatementError)
    end
  end

  # A valid window table statement is counted in place, and the outer
  # statement is counted too.
  describe "a window whose window table statement is valid" do
    let(:table) { [ "date_range", { "start" => "1900-01-01", "end" => "2100-12-31" } ] }
    let(:statement) { [ "window", [ "icd9", "412" ], { "window_table" => table } ] }

    it "keeps the window at the top and counts both statements" do
      annotated = CDB.query(statement).annotate
      _(annotated.first).must_equal "window"
      _(annotated[1]).must_equal CDB.query([ "icd9", "412" ]).annotate
      _(annotated.last[:window_table]).must_equal CDB.query(table).annotate
      _(CDB.query(statement).valid?).must_equal true
    end
  end

  # conceptql-ypog: one of start_date and end_date without the other was
  # ignored with no warning, and an unknown scope_by raised a RuntimeError
  # when the SQL was built. Now both are errors of the window operator, from
  # the window statement or from the scope options of a calling program.
  describe "a window with invalid window options" do
    missing = ConceptQL::Window::MISSING_DATE_ERROR
    scope_by = ConceptQL::Window::SCOPE_BY_ERROR
    {
      "only start_date" => [ { "start_date" => "2010-01-01" }, [ missing, "end_date" ] ],
      "only end_date" => [ { "end_date" => "2010-12-31" }, [ missing, "start_date" ] ],
      "an unknown scope_by" => [ { "scope_by" => "foo" }, [ scope_by, "foo" ] ]
    }.each do |name, (window_options, (message, *details))|
      errors = [ { operator: "window", id: "window-1", message: message, details: details } ]
      line = "  window: #{message} (#{details.join(', ')})"

      describe "with #{name} in the window statement" do
        let(:statement) { [ "window", [ "icd9", "412" ], window_options ] }

        it "reports the error on the window operator" do
          query = CDB.query(statement)
          _(query.errors).must_equal(errors)
          _(query.valid?).must_equal false
          _(query.validation_errors).must_equal(errors)
        end

        it "builds no SQL" do
          error = _ { CDB.query(statement).sql }.must_raise(ConceptQL::InvalidStatementError)
          _(error.errors).must_equal(errors)
          _(error.message).must_include(line)
          _ { CDB.query(statement).count }.must_raise(ConceptQL::InvalidStatementError)
        end

        it "annotates with counts and does not count" do
          annotated = CDB.query(statement).annotate
          _(annotated.first).must_equal "window"
          _(annotated[1].last[:annotation][:counts]).must_equal({ condition_occurrence: { rows: 0, n: 0 } })
          _(annotated.last[:annotation]).must_equal({ id: "window-1", errors: [ [ message, *details ] ] })
        end
      end

      # conceptql-0vwh: String keys in the scope options had no effect.
      { "Symbol" => :to_sym, "String" => :to_s }.each do |kind, key_type|
        describe "with #{name} in the scope options with #{kind} keys" do
          let(:query) { CDB.query([ "icd9", "412" ], scope_opts: window_options.transform_keys(&key_type)) }

          it "reports the error on a window operator around the statement" do
            _(query.errors).must_equal(errors)
            _(query.annotate(skip_counts: true).first).must_equal "window"
          end

          it "builds no SQL" do
            error = _ { query.sql }.must_raise(ConceptQL::InvalidStatementError)
            _(error.errors).must_equal(errors)
          end
        end
      end
    end

    it "reports both errors of one window" do
      query = CDB.query([ "window", [ "icd9", "412" ], { "end_date" => "2010-12-31", "scope_by" => :bar } ])
      _(query.errors.map { |error| [ error[:message], *error[:details] ] })
        .must_equal [ [ missing, "start_date" ], [ scope_by, "bar" ] ]
    end

    it "keeps the raise of Window.prep_options as an assertion" do
      error = _ { ConceptQL::Window.prep_options(scope_by: "foo") }.must_raise(RuntimeError)
      _(error.message).must_equal "#{scope_by}: :foo"
    end
  end

  describe "a window with valid window options" do
    [ nil, "start_date", "end_date", "date_range", :date_range ].each do |scope_by|
      it "builds the SQL of both dates with scope_by #{scope_by.inspect}" do
        options = { "start_date" => "2008-01-01", "end_date" => "2010-12-31", "scope_by" => scope_by }
        query = CDB.query([ "window", [ "icd9", "412" ], options ])
        _(query.errors).must_be_empty
        _(query.sql).must_match(/SELECT/i)
        _(query.count).must_be_kind_of(Integer)
      end
    end

    it "does not wrap a statement whose scope options are valid" do
      query = CDB.query([ "icd9", "412" ], scope_opts: { start_date: "2008-01-01", end_date: "2010-12-31" })
      _(query.annotate(skip_counts: true).first).must_equal "icd9"
      _(query.valid?).must_equal true
    end
  end

  # conceptql-0vwh: Database#query did not rekey the scope options, so window
  # options with String keys (from a calling program that reads JSON) had no
  # effect, and the statement ran over all dates.
  describe "window options with String keys in the scope options" do
    statement = [ "icd9", "412" ]
    # The CTE names end in a random hex.
    sql = ->(query) { query.sql.gsub(/_\h{32}\b/, "_HEX") }
    stringify = ->(hash) { hash.to_h { |key, value| [ key.to_s, value.is_a?(Hash) ? stringify.call(value) : value ] } }
    # A calling program gives a window table as a table name or a dataset.
    let(:window_table) { CDB.query([ "date_range", { start: "2008-01-01", end: "2008-12-31" } ]).query }
    {
      "a window table" => ->(table) { { window_table: table, scope_by: "end_date" } },
      "a date range" => ->(_table) { { start_date: "2008-01-01", end_date: "2008-12-31" } },
      "a window table in window_opts" => ->(table) { { window_opts: { window_table: table } } }
    }.each do |name, options_for|
      it "uses #{name} as Symbol keys do" do
        options = options_for.call(window_table)
        symbol_query = CDB.query(statement, scope_opts: options)
        string_query = CDB.query(statement, scope_opts: stringify.call(options))
        _(sql.call(string_query)).must_equal sql.call(symbol_query)
        _(string_query.query.order(:criterion_id).all).must_equal symbol_query.query.order(:criterion_id).all
        _(string_query.count).wont_equal CDB.query(statement).count
      end
    end

    it "uses the String keys of the scope options of a Database" do
      symbol_query, string_query = [ { start_date: "2008-01-01", end_date: "2008-12-31" },
                                     { "start_date" => "2008-01-01", "end_date" => "2008-12-31" } ].map do |scope_opts|
        ConceptQL::Database.new(DB, data_model: CDB.opts[:data_model], scope_opts: scope_opts).query(statement)
      end
      _(sql.call(string_query)).must_equal sql.call(symbol_query)
      _(string_query.count).wont_equal CDB.query(statement).count
    end
  end

  # conceptql-5dh8: the options of an inner window replace those of an outer
  # window in the scope, so the SQL runs with the inner options. The
  # annotation merged the two, so the diagram showed options that did not
  # run (here the outer scope_by).
  describe "a window inside a window" do
    statement = [ "icd9", "412" ]
    inner = { start_date: "2008-01-01", end_date: "2008-12-31" }
    outer = { start_date: "2009-01-01", end_date: "2009-12-31", scope_by: "end_date" }
    let(:query) { CDB.query([ "window", [ "window", statement, inner ], outer ]) }
    # The CTE names end in a random hex.
    sql = ->(query) { query.sql.gsub(/_\h{32}\b/, "_HEX") }

    it "builds the SQL of the inner window, as before" do
      _(sql.call(query)).must_equal sql.call(CDB.query([ "window", statement, inner ]))
    end

    it "annotates the options of the inner window" do
      _(query.annotate(skip_counts: true).first).must_equal "window"
      _(query.annotate(skip_counts: true).last).must_equal({ **inner, annotation: { id: "window-1" } })
      _(query.annotate.last).must_equal({ **inner, annotation: { id: "window-1" } })
    end

    it "checks the options of the inner window" do
      missing = [ ConceptQL::Window::MISSING_DATE_ERROR, "end_date" ]
      inner_error = CDB.query([ "window", [ "window", statement, { start_date: "2008-01-01" } ], outer ])
      _(inner_error.errors.map { |error| [ error[:message], *error[:details] ] }).must_equal [ missing ]
      _(inner_error.annotate(skip_counts: true).last)
        .must_equal({ start_date: "2008-01-01", annotation: { id: "window-1", errors: [ missing ] } })
      outer_error = CDB.query([ "window", [ "window", statement, inner ], { start_date: "2009-01-01" } ])
      _(outer_error.errors).must_be_empty
    end
  end

  # conceptql-xdmk: only a window statement gave Window::Table the Database
  # that queries a window table statement, so a window table statement in the
  # scope options raised NoMethodError.
  describe "a window table statement in the scope options" do
    statement = [ "icd9", "412" ]
    table = [ "date_range", { "start" => "2008-01-01", "end" => "2008-12-31" } ]
    # The CTE names end in a random hex.
    sql = ->(query) { query.sql.gsub(/_\h{32}\b/, "_HEX") }
    rows = ->(query) { query.query.order(:criterion_id).all }
    let(:window_statement) { CDB.query([ "window", statement, { window_table: table } ]) }

    {
      "in window_opts" => { window_opts: { window_table: table } },
      "in window_opts, with String keys" => { "window_opts" => { "window_table" => table } }
    }.each do |name, scope_opts|
      it "runs and annotates #{name} as a window statement does" do
        query = CDB.query(statement, scope_opts: scope_opts)
        _(sql.call(query)).must_equal sql.call(window_statement)
        _(rows.call(query)).must_equal rows.call(window_statement)
        _(query.annotate(skip_counts: true)).must_equal window_statement.annotate(skip_counts: true)
      end
    end

    # A window table at the top of the scope options does not add window_id
    # to the columns that operators match on, for a table name too, so the
    # SQL differs. The rows are the same.
    it "gives the rows of a window statement at the top of the scope options" do
      query = CDB.query(statement, scope_opts: { "window_table" => table })
      _(rows.call(query)).must_equal rows.call(window_statement)
      _(query.count).wont_equal CDB.query(statement).count
    end

    it "reports the errors of the window table statement" do
      invalid = [ "provider_filter", [ "icd9", "412" ], { "specialties" => "*" } ]
      query = CDB.query(statement, scope_opts: { window_table: invalid })
      _(query.errors.map { |error| [ error[:operator], error[:message], *error[:details] ] })
        .must_equal [ [ "provider_filter", "required option not present", "roles" ] ]
      _ { query.query }.must_raise ConceptQL::InvalidStatementError
    end

    it "checks the window options" do
      query = CDB.query(statement, scope_opts: { window_table: table, scope_by: "bogus" })
      _(query.errors.map { |error| [ error[:operator], error[:message], *error[:details] ] })
        .must_equal [ [ "window", ConceptQL::Window::SCOPE_BY_ERROR, "bogus" ] ]
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
      "recall/anno_6.json" => "recall: no matching label (Qualifying Meyloma Dx)"
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
    # it is only a warning.
    it "should not raise on a statement with only warnings" do
      query = CDB.query(%w[icd9 412 000.00])
      _(query.warnings).wont_be_empty
      _(query.code_list.map(&:code)).must_equal(%w[412 000.00])
    end

    # A malformed code is a warning, not an error (seeds conceptql-0eb and
    # conceptql-ysx, ruled 2026-10-30).
    it "should not raise on a statement whose only problem is a malformed code" do
      _(CDB.query(%w[icd9 412 XYZ]).code_list.map(&:code)).must_equal(%w[412 XYZ])
      _(CDB.query(JSON.parse(File.read("test/statements/icd9/anno_invalid_code.json"))).code_list).wont_be_empty
    end

    it "should not change what a later annotate returns" do
      statement = [ "union", %w[icd9 412 000.00], %w[cpt 99214] ]
      query = CDB.query(statement)
      query.code_list
      _(query.annotate).must_equal(CDB.query(statement).annotate)
    end
  end
end

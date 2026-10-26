# frozen_string_literal: true

require_relative "../../helper"

describe ConceptQL::Scope do
  describe "using postgres" do
    let(:host) { :postgres }

    describe "with a table_prefix" do
      let(:opts) do
        { scope_opts: { table_prefix: "jtemp123456" } }
      end

      it "should use prefix in table name" do
        if ENV["CONCEPTQL_AVOID_CTES"] == "true"
          skip
        else
          db = ConceptQL::Database.new(
            Sequel.mock(host: host),
            data_model: :gdm,
            force_temp_tables: true,
            scratch_database: "jigsaw_temp"
          )
          _(db.query(
            [ "ADMSRCE", "12", { label: "test label" } ],
            opts
          ).sql).must_match(/jtemp123456/)
        end
      end
    end

    describe "with date literal windows" do
      let(:opts) do
        { scope_opts: { start_date: "2001-01-01", end_date: "2001-12-31" } }
      end

      it "should limit selection by date range under gdm" do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        cql_sql = db.query(%w[ADMSRCE 12], opts).sql
        assert_match(
          /WHERE \(\(CAST\('2001-01-01' AS date\) <= "start_date"\) AND \("start_date" <= CAST\('2001-12-31' AS date\)\)\)\)/, cql_sql
        )
      end
    end

    describe "with windows from another table" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it "should limit selection by date range under gdm" do
        db = Sequel.mock(host: host)
        cdb = ConceptQL::Database.new(db, data_model: :gdm)
        db.add_table_schema(:jtemp, [ [ :person_id ], [ :start_date ], [ :end_date ] ])
        cql_sql = cdb.query(%w[ADMSRCE 12], opts).sql
        assert_match(/FROM "jtemp"/, cql_sql)
        assert_match(/"r"."start_date" <= "l"."start_date"/, cql_sql)
        assert_match(/"l"."start_date" <= "r"."end_date"/, cql_sql)
      end
    end

    describe "with windows from another table, along with adjustments" do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start: "-30d", adjust_window_end: "1m" } }
      end

      it "should limit selection by date range under gdm" do
        db = Sequel.mock(host: host)
        cdb = ConceptQL::Database.new(db, data_model: :gdm)
        db.add_table_schema(:jtemp, [ [ :person_id ], [ :start_date ], [ :end_date ] ])
        cql_sql = cdb.query(%w[ADMSRCE 12], opts).sql
        assert_match(/FROM "jtemp"/, cql_sql)
        assert_match(/make_interval\(days := -30\)/, cql_sql)
        assert_match(/make_interval\(months := 1\)/, cql_sql)
      end
    end
  end

  describe "using duckdb" do
    let(:host) { :duckdb }

    it "orders extracted ctes before dependent recalls" do
      sequel_db = Sequel.mock(host: host)
      scope = ConceptQL::Scope.new
      ctes = []

      label_ds = sequel_db[:patients]
      recall_ds = sequel_db[:label1].with(:label1, label_ds)
      query = sequel_db[:recall].with(:recall, recall_ds)

      scope.send(:recursive_extract_ctes, query, ctes)

      _(ctes.map(&:first)).must_equal(%i[label1 recall])
    end

    it "sorts extracted ctes by dependency order" do
      sequel_db = Sequel.mock(host: host)
      scope = ConceptQL::Scope.new
      label_ds = sequel_db[:patients]
      recall_ds = sequel_db[:label1]

      sorted = scope.send(:sort_extracted_ctes, [ [ :recall, recall_ds ], [ :label1, label_ds ] ])

      _(sorted.map(&:first)).must_equal(%i[label1 recall])
    end

    it "renders dependent ctes after their prerequisites in sql" do
      sequel_db = Sequel.mock(host: host)
      scope = ConceptQL::Scope.new
      query = sequel_db[:result].with(:recall, sequel_db[:label1]).from_self
      ctes = [ [ :label1, sequel_db[:patients] ] ]

      query = scope.send(:recursive_extract_ctes, query, ctes)
      ctes = scope.send(:sort_extracted_ctes, ctes)

      ctes.each do |table_name, ds|
        query = query.with(table_name, ds)
      end

      sql = query.sql
      _(sql.index('"label1" AS')).must_be :<, sql.index('"recall" AS')
    end

    # Scope#cte_name returns Identifier names, and a QualifiedIdentifier name
    # for a temp table in a scratch database.
    describe "with identifier names" do
      let(:sequel_db) { Sequel.mock(host: host) }
      let(:scope) { ConceptQL::Scope.new }
      let(:label) { Sequel.identifier("label_1_abc") }
      let(:recall) { Sequel.identifier("recall_2_abc") }

      def sorted_names(ctes)
        scope.send(:sort_extracted_ctes, ctes).map(&:first)
      end

      it "moves a cte after the identifier it reads" do
        ctes = [ [ recall, sequel_db.from(label) ], [ label, sequel_db[:patients] ] ]

        _(sorted_names(ctes)).must_equal([ label, recall ])
      end

      it "moves a cte after the qualified identifier it reads" do
        label = self.label.qualify(:jigsaw_temp)
        recall = self.recall.qualify(:jigsaw_temp)
        ctes = [ [ recall, sequel_db.from(label) ], [ label, sequel_db[:patients] ] ]

        _(sorted_names(ctes)).must_equal([ label, recall ])
      end

      it "does not match a name inside a longer name" do
        short = Sequel.identifier("label_1").qualify(:jigsaw_temp)
        long = Sequel.identifier("label_10").qualify(:jigsaw_temp)
        ctes = [ [ recall, sequel_db.from(long) ], [ long, sequel_db[:patients] ], [ short, sequel_db[:patients] ] ]

        _(sorted_names(ctes)).must_equal([ long, recall, short ])
      end

      it "keeps an incoming order that is already correct" do
        other = Sequel.identifier("other_3_abc")
        ctes = [ [ label, sequel_db[:patients] ], [ recall, sequel_db.from(label) ], [ other, sequel_db[:patients] ] ]

        _(sorted_names(ctes)).must_equal([ label, recall, other ])
      end

      it "raises when the ctes read each other in a cycle" do
        ctes = [ [ recall, sequel_db.from(label) ], [ label, sequel_db.from(recall) ] ]

        _ { sorted_names(ctes) }.must_raise(ConceptQL::Scope::CteCycleError)
      end
    end
  end
end

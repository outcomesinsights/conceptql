# frozen_string_literal: true

require_relative "../../../helper"

describe ConceptQL::Operators::Numeric do
  let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  describe "introspection methods" do
    describe "without upstream (as_criterion path — single row per patient)" do
      let(:query) { db.query([ :numeric, 1 ]) }

      it "returns events_per_patient :single via Numeric override" do
        # The override lives on Numeric itself (not the base Operator). The
        # SELECT value_as_number FROM patients shape produces exactly one row
        # per patient, so events_per_patient must be :single — otherwise
        # downstream operators that aggregate via :all-single-then-single
        # (Union, CoReported) misclassify the cardinality.
        _(query.operator.method(:events_per_patient).owner).must_equal ConceptQL::Operators::Numeric
        _(query.events_per_patient).must_equal :single
      end

      it "returns multiple_vocabularies false" do
        _(query.multiple_vocabularies).must_equal false
      end

      it "has no vocabularies — numeric is not a vocabulary operator" do
        _(query.operator.vocabularies).must_equal []
      end
    end

    describe "with upstream (with_kids path — inherits from upstream)" do
      it "inherits events_per_patient :multiple from a multi-event upstream" do
        query = db.query([ :numeric, 1, [ :icd9, "250.00" ] ])

        _(query.events_per_patient).must_equal :multiple
      end

      it "inherits events_per_patient :single from a single-event upstream" do
        query = db.query([ :numeric, 1, [ :first, [ :icd9, "250.00" ] ] ])

        _(query.events_per_patient).must_equal :single
      end

      it "inherits multiple_vocabularies from upstream (single vocab)" do
        query = db.query([ :numeric, 1, [ :icd9, "250.00" ] ])

        _(query.multiple_vocabularies).must_equal false
      end

      it "aggregates vocabularies from upstream" do
        query = db.query([ :numeric, 1, [ :icd9, "250.00" ] ])

        _(query.operator.vocabularies).must_equal [ "ICD9CM" ]
      end
    end

    describe "wrapped in Union (cascade from leaf override)" do
      it "union(numeric, numeric) reports :multiple although both leaves are :single" do
        # Each numeric leaf gives one row per person, and union passes along
        # the rows of both. On the DuckDB fixture, each of the 249 persons
        # gets two rows (bead conceptql-8q8h).
        query = db.query([ :union, [ :numeric, 1 ], [ :numeric, 2 ] ])

        _(query.events_per_patient).must_equal :multiple
      end

      it "union(numeric) reports :single from its one leaf" do
        query = db.query([ :union, [ :numeric, 1 ] ])

        _(query.events_per_patient).must_equal :single
      end

      it "union(numeric, numeric) reports multiple_vocabularies false" do
        query = db.query([ :union, [ :numeric, 1 ], [ :numeric, 2 ] ])

        _(query.multiple_vocabularies).must_equal false
      end
    end
  end

  # With an upstream, a column name in the argument is read from the rows the
  # upstream emits (SELECT ... FROM (<upstream>)). Every stream emits the
  # same columns, the scope's query columns, whatever tables it reads. A name
  # outside them fails at run time, so validation reports it (bead
  # conceptql-2xf).
  describe "column name argument with an upstream" do
    def errors_for(cdb, statement)
      cdb.query(statement).annotate.last[:annotation][:errors]
    end

    %i[gdm gdm_wide].each do |data_model|
      describe "in #{data_model}" do
        let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: data_model) }

        it "reports a column that the upstream rows lack, by name" do
          _(errors_for(cdb, [ "numeric", "quantity", [ "icd9", "412" ] ])).must_equal [ [ "unknown column", "quantity" ] ]
        end

        it "reports the column for an upstream that mixes tables" do
          statement = [ "numeric", "quantity", [ "union", [ "icd9", "412" ], [ "ndc", "0000001" ] ] ]

          _(errors_for(cdb, statement)).must_equal [ [ "unknown column", "quantity" ] ]
        end

        it "accepts a column that every stream emits" do
          _(errors_for(cdb, [ "numeric", "criterion_id", [ "icd9", "412" ] ])).must_be_nil
        end

        it "accepts a column name in another case, as DuckDB and Spark do" do
          _(errors_for(cdb, [ "numeric", "Criterion_ID", [ "icd9", "412" ] ])).must_be_nil
        end

        it "accepts a column that another operator in the statement adds to the rows" do
          statement = [ "numeric", "provider_id", [ "provider_filter", [ "icd9", "412" ], { specialties: "12345", roles: "*" } ] ]

          _(errors_for(cdb, statement)).must_be_nil
        end

        it "reads the column from the upstream rows in the SQL" do
          _(cdb.query([ "numeric", "criterion_id", [ "icd9", "412" ] ]).sql).must_match(/CAST\("criterion_id" AS Float\) AS "value_as_number"/)
        end

        # Postgres folds only unquoted names, and the SQL quotes the name, so
        # the SQL must spell the column as the rows do (bead conceptql-4bd).
        it "reads a column named in another case by its real name in the SQL" do
          _(cdb.query([ "numeric", "Criterion_ID", [ "icd9", "412" ] ]).sql).must_match(/CAST\("criterion_id" AS Float\) AS "value_as_number"/)
        end

        it "accepts a number" do
          _(errors_for(cdb, [ "numeric", 1, [ "icd9", "412" ] ])).must_be_nil
          _(errors_for(cdb, [ "numeric", "-2.5", [ "icd9", "412" ] ])).must_be_nil
        end
      end
    end
  end

  # Without an upstream, a column name in the argument is read from the
  # person table (SELECT ... FROM patients, in gdm and gdm_wide). A name
  # outside that table's columns fails at run time, so validation reports it
  # (bead conceptql-oyi).
  describe "column name argument without an upstream" do
    def errors_for(cdb, statement)
      cdb.query(statement).annotate.last[:annotation][:errors]
    end

    %i[gdm gdm_wide].each do |data_model|
      describe "in #{data_model}" do
        let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: data_model) }

        it "reports a column that the person table lacks, by name" do
          _(errors_for(cdb, [ "numeric", "no_such_column" ])).must_equal [ [ "unknown column", "no_such_column" ] ]
        end

        it "reports a column that only the upstream rows have" do
          _(errors_for(cdb, [ "numeric", "criterion_id" ])).must_equal [ [ "unknown column", "criterion_id" ] ]
        end

        it "runs no SQL to validate" do
          query = cdb.query([ "numeric", "no_such_column" ])
          query.operator
          cdb.db.sqls # Sequel's mock returns and clears the lexicon's setup queries

          query.annotate(skip_counts: true)

          _(cdb.db.sqls).must_equal []
        end

        it "accepts a column of the person table" do
          _(errors_for(cdb, [ "numeric", "gender_concept_id" ])).must_be_nil
        end

        it "accepts a column name in another case, as DuckDB and Spark do" do
          _(errors_for(cdb, [ "numeric", "Gender_Concept_ID" ])).must_be_nil
        end

        it "reads the column from the person table in the SQL" do
          _(cdb.query([ "numeric", "gender_concept_id" ]).sql).must_match(/CAST\("gender_concept_id" AS Float\) AS "value_as_number" FROM "patients"/)
        end

        it "reads a column named in another case by its real name in the SQL" do
          _(cdb.query([ "numeric", "Gender_Concept_ID" ]).sql).must_match(/CAST\("gender_concept_id" AS Float\) AS "value_as_number" FROM "patients"/)
        end

        it "accepts a number" do
          _(errors_for(cdb, [ "numeric", 1 ])).must_be_nil
          _(errors_for(cdb, [ "numeric", "-2.5" ])).must_be_nil
        end
      end
    end
  end

  describe "column_family in generated SQL" do
    it "as_criterion path emits default column_family" do
      # Numeric#as_criterion explicitly sets column_family to
      # DEFAULT_COLUMN_FAMILY in its selectify replace hash. Without that
      # explicit replace, the patients table lacks a column_family column,
      # nullified_columns inserts CAST(NULL AS text), and the outer
      # evaluate -> select_it wrap does NOT re-inject a value (Numeric has no
      # source_table/table/domain methods). The replace at the inner level is
      # what guarantees the default is emitted.
      query = db.query([ :numeric, 1 ])
      sql = query.sql

      _(sql).must_match(/CAST\('default' AS text\) AS "column_family"/)
      _(sql).wont_match(/CAST\(NULL AS text\) AS "column_family"/)
    end

    it "with_kids path emits default column_family (inherits from upstream)" do
      # When Numeric has an upstream, with_kids passes the upstream dataset through
      # selectify in the pass-through path (no domain/query_columns), so column_family
      # flows through from the upstream operator's value of 'default'.
      query = db.query([ :numeric, 1, [ :icd9, "250.00" ] ])
      sql = query.sql

      _(sql).must_match(/CAST\('default' AS text\) AS "column_family"/)
    end
  end
end

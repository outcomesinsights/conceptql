# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::Numeric do
  let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  describe 'introspection methods' do
    describe 'without upstream (as_criterion path — single row per patient)' do
      let(:query) { db.query([:numeric, 1]) }

      it 'returns events_per_patient :single via Numeric override' do
        # The override lives on Numeric itself (not the base Operator). The
        # SELECT value_as_number FROM patients shape produces exactly one row
        # per patient, so events_per_patient must be :single — otherwise
        # downstream operators that aggregate via :all-single-then-single
        # (Union, CoReported, ConcurrentWithin) misclassify the cardinality.
        _(query.operator.method(:events_per_patient).owner).must_equal ConceptQL::Operators::Numeric
        _(query.events_per_patient).must_equal :single
      end

      it 'returns multiple_vocabularies false' do
        _(query.multiple_vocabularies).must_equal false
      end

      it 'has no vocabularies — numeric is not a vocabulary operator' do
        _(query.operator.vocabularies).must_equal []
      end
    end

    describe 'with upstream (with_kids path — inherits from upstream)' do
      it 'inherits events_per_patient :multiple from a multi-event upstream' do
        query = db.query([:numeric, 1, [:icd9, '250.00']])
        _(query.events_per_patient).must_equal :multiple
      end

      it 'inherits events_per_patient :single from a single-event upstream' do
        query = db.query([:numeric, 1, [:first, [:icd9, '250.00']]])
        _(query.events_per_patient).must_equal :single
      end

      it 'inherits multiple_vocabularies from upstream (single vocab)' do
        query = db.query([:numeric, 1, [:icd9, '250.00']])
        _(query.multiple_vocabularies).must_equal false
      end

      it 'aggregates vocabularies from upstream' do
        query = db.query([:numeric, 1, [:icd9, '250.00']])
        _(query.operator.vocabularies).must_equal ['ICD9CM']
      end
    end

    describe 'wrapped in Union (cascade from leaf override)' do
      it 'union(numeric, numeric) reports :single because both leaves are :single' do
        # Union returns :single only when ALL upstreams are :single. Both
        # numeric leaves use the as_criterion path and report :single via
        # the override, so Union also reports :single.
        query = db.query([:union, [:numeric, 1], [:numeric, 2]])
        _(query.events_per_patient).must_equal :single
      end

      it 'union(numeric, numeric) reports multiple_vocabularies false' do
        query = db.query([:union, [:numeric, 1], [:numeric, 2]])
        _(query.multiple_vocabularies).must_equal false
      end
    end
  end

  describe 'column_family in generated SQL' do
    it 'as_criterion path emits default column_family' do
      # Numeric#as_criterion explicitly sets column_family to
      # DEFAULT_COLUMN_FAMILY in its selectify replace hash. Without that
      # explicit replace, the patients table lacks a column_family column,
      # nullified_columns inserts CAST(NULL AS text), and the outer
      # evaluate -> select_it wrap does NOT re-inject a value (Numeric has no
      # source_table/table/domain methods). The replace at the inner level is
      # what guarantees the default is emitted.
      query = db.query([:numeric, 1])
      sql = query.sql
      _(sql).must_match(/CAST\('default' AS text\) AS "column_family"/)
      _(sql).wont_match(/CAST\(NULL AS text\) AS "column_family"/)
    end

    it 'with_kids path emits default column_family (inherits from upstream)' do
      # When Numeric has an upstream, with_kids passes the upstream dataset through
      # selectify in the pass-through path (no domain/query_columns), so column_family
      # flows through from the upstream operator's value of 'default'.
      query = db.query([:numeric, 1, [:icd9, '250.00']])
      sql = query.sql
      _(sql).must_match(/CAST\('default' AS text\) AS "column_family"/)
    end
  end
end

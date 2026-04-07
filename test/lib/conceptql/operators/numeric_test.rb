# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::Numeric do
  let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  # WARNING: Every assertion in this block documents CURRENT pre-fix behavior.
  # When conceptql-n61 lands, verify EACH assertion against the bead description
  # before updating. Do NOT flip assertions one at a time in response to test
  # failures. The bead specifies exactly which assertions should change and to
  # what values. See conceptql-n61 for the full fix specification.
  describe 'introspection methods (CURRENT BEHAVIOR — pinned before conceptql-n61)' do
    describe 'without upstream (as_criterion path — flips to :single in conceptql-n61)' do
      let(:query) { db.query([:numeric, 1]) }

      it 'returns events_per_patient :multiple via Operator#events_per_patient leaf fallback' do
        # Verify the value comes from the base Operator's leaf default, not a Numeric override.
        _(query.operator.method(:events_per_patient).owner).must_equal ConceptQL::Operators::Operator
        _(query.events_per_patient).must_equal :multiple
      end

      it 'returns multiple_vocabularies false (anchor — should not change in n61)' do
        _(query.multiple_vocabularies).must_equal false
      end

      it 'has no vocabularies — numeric is not a vocabulary operator (anchor)' do
        _(query.operator.vocabularies).must_equal []
      end
    end

    describe 'with upstream (with_kids path — should NOT change in n61)' do
      it 'inherits events_per_patient :multiple from a multi-event upstream' do
        query = db.query([:numeric, 1, [:icd9, '250.00']])
        _(query.events_per_patient).must_equal :multiple
      end

      it 'inherits events_per_patient :single from a single-event upstream (anchor)' do
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

    describe 'wrapped in Union (CURRENT — flips when n61 lands)' do
      it 'union(numeric, numeric) reports :multiple (CURRENT — flips to :single after n61 since both leaves become :single)' do
        # Union returns :single only when ALL upstreams are :single. Today the leaves
        # are :multiple, so Union is :multiple. After n61, the leaves become :single,
        # so Union becomes :single. Pin this NOW so the cascade is visible.
        query = db.query([:union, [:numeric, 1], [:numeric, 2]])
        _(query.events_per_patient).must_equal :multiple
      end

      it 'union(numeric, numeric) reports multiple_vocabularies false (anchor)' do
        query = db.query([:union, [:numeric, 1], [:numeric, 2]])
        _(query.multiple_vocabularies).must_equal false
      end
    end
  end

  describe 'column_family in generated SQL (latent bug tracked by conceptql-n61)' do
    it 'as_criterion path emits NULL column_family (BUG — should emit DEFAULT_COLUMN_FAMILY after n61)' do
      # CURRENT BEHAVIOR: Numeric#as_criterion calls dm.selectify directly with
      # `domain: :person`. The selectify path nullifies any DEFAULT_COLUMNS not
      # present in the patients table — including column_family. The outer
      # evaluate -> select_it wrap does not re-inject column_family because the
      # outer selectify just selects the existing (NULL) column_family column
      # from the inner query.
      #
      # This assertion locks in the bug. After conceptql-n61 fixes the root cause,
      # the must_match should expect `CAST('default' AS text) AS "column_family"`
      # and the wont_match should expect `CAST(NULL AS text) AS "column_family"`.
      query = db.query([:numeric, 1])
      sql = query.sql
      _(sql).must_match(/CAST\(NULL AS text\) AS "column_family"/)
      _(sql).wont_match(/CAST\('default' AS text\) AS "column_family"/)
    end

    it 'with_kids path emits default column_family (anchor — should not change in n61)' do
      # When Numeric has an upstream, with_kids passes the upstream dataset through
      # selectify in the pass-through path (no domain/query_columns), so column_family
      # flows through from the upstream operator's value of 'default'.
      query = db.query([:numeric, 1, [:icd9, '250.00']])
      sql = query.sql
      _(sql).must_match(/CAST\('default' AS text\) AS "column_family"/)
    end
  end
end

# frozen_string_literal: true

require_relative '../../../helper'

describe ConceptQL::Operators::Episode do
  it 'uses postgres-style interval SQL for duckdb date adjustments' do
    sequel_db = Sequel.mock(host: :duckdb)
    db = ConceptQL::Database.new(sequel_db, data_model: :gdm)
    operator = db.query([:episode, [:from, 'patients']]).operator

    sql = sequel_db.literal(operator.send(:date_adjust_add, sequel_db, Sequel[:start_date], Sequel[2], 'days'))

    _(sql).must_match(/INTERVAL '1' day/i)
    _(sql).must_match(/CAST\(/)
  end

  it 'uses duckdb datediff with an explicit day unit' do
    rdbms = ConceptQL::Rdbms::DuckDB.new
    sql = Sequel.mock(host: :duckdb).literal(rdbms.datediff(:episode_start_date, :episode_end_date))

    _(sql).must_match(/datediff\('day', "episode_end_date", "episode_start_date"\)/i)
  end

  # WARNING: Every assertion in this block documents CURRENT pre-fix behavior.
  # When conceptql-grt lands, verify EACH assertion against the bead description
  # before updating. Do NOT flip assertions one at a time in response to test
  # failures. The bead specifies exactly which assertions should change and to
  # what values. See conceptql-grt for the full fix specification.
  describe 'introspection methods (CURRENT BEHAVIOR — pinned before conceptql-grt)' do
    let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

    describe 'events_per_patient (Episode forwards to upstream — should NOT change in grt)' do
      it 'inherits :multiple from a multi-event upstream' do
        query = db.query([:episode, [:icd9, '250.00']])
        _(query.events_per_patient).must_equal :multiple
      end

      it 'forwards to upstream regardless of direction (proves Episode walks, not hardcodes)' do
        # If Episode hardcodes a return value, multi and single will collapse.
        multi = db.query([:episode, [:icd9, '250.00']])
        single = db.query([:episode, [:first, [:icd9, '250.00']]])
        _(multi.events_per_patient).must_equal :multiple
        _(single.events_per_patient).must_equal :single
        _(multi.events_per_patient).wont_equal single.events_per_patient
      end

      it 'forwards to upstream value identically (anchor — should not change in grt)' do
        upstream_query = db.query([:first, [:icd9, '250.00']])
        episode_query = db.query([:episode, [:first, [:icd9, '250.00']]])
        _(episode_query.events_per_patient).must_equal upstream_query.events_per_patient
      end
    end

    describe 'multiple_vocabularies (CURRENT — flips to false in conceptql-grt)' do
      it 'returns false when upstream has a single vocabulary (anchor — should not change)' do
        query = db.query([:episode, [:icd9, '250.00']])
        _(query.multiple_vocabularies).must_equal false
      end
    end

    describe 'vocabularies (CURRENT — flips to [] in conceptql-grt)' do
      it 'walks through to upstream vocabulary IDs' do
        # CURRENT BEHAVIOR: Episode does not override #vocabularies, so the default
        # implementation collects vocabulary IDs from upstreams. After conceptql-grt
        # this should return [].
        query = db.query([:episode, [:icd9, '250.00']])
        _(query.operator.vocabularies).must_equal ['ICD9CM']
      end
    end

    # Cross-cutting test: variadic operators wrapping episodes.
    # The conceptql-grt fix MUST override BOTH Episode#vocabularies AND
    # Episode#multiple_vocabularies. If only multiple_vocabularies is overridden,
    # these tests will still report `true` because the variadic operators fall back
    # to `vocabularies.length > 1` (see union.rb, co_reported.rb, concurrent_within.rb).
    # That cross-check is the entire point of these tests — do NOT loosen them.
    [
      [:union],
      [:co_reported]
    ].each do |op, *opts|
      describe "wrapped in #{op} (CURRENT — flips to false/[] in conceptql-grt)" do
        let(:query) do
          db.query([op, [:episode, [:icd9, '250.00']], [:episode, [:cpt, '99214']], *opts])
        end

        it "#{op}#multiple_vocabularies returns true via vocabularies aggregation" do
          _(query.multiple_vocabularies).must_equal true
        end

        it "#{op}#vocabularies aggregates upstream vocabs through Episode" do
          _(query.operator.vocabularies).must_equal %w[ICD9CM CPT4]
        end
      end
    end

    describe 'wrapped in concurrent_within (CURRENT — flips to false/[] in conceptql-grt)' do
      let(:query) do
        db.query([:concurrent_within, [:episode, [:icd9, '250.00']], [:episode, [:cpt, '99214']],
                  { 'within' => '0d' }])
      end

      it 'concurrent_within#multiple_vocabularies returns true via vocabularies aggregation' do
        _(query.multiple_vocabularies).must_equal true
      end

      it 'concurrent_within#vocabularies aggregates upstream vocabs through Episode' do
        _(query.operator.vocabularies).must_equal %w[ICD9CM CPT4]
      end
    end

    # Anchor: bare vocabulary (no Episode wrapper) must not be affected by the grt fix.
    describe 'anchors (must NOT change in conceptql-grt)' do
      it 'bare icd9 still reports vocabularies = [ICD9CM]' do
        query = db.query([:icd9, '250.00'])
        _(query.operator.vocabularies).must_equal ['ICD9CM']
      end

      it 'bare icd9 still reports multiple_vocabularies = false' do
        query = db.query([:icd9, '250.00'])
        _(query.multiple_vocabularies).must_equal false
      end

      it 'union of two icd9 codes still reports multiple_vocabularies = false' do
        query = db.query([:union, [:icd9, '250.00'], [:icd9, '401.1']])
        _(query.multiple_vocabularies).must_equal false
      end
    end
  end
end

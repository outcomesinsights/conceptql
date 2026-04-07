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

  # Episode strips source_vocabulary_id from its output (the SQL emits NULL),
  # so downstream consumers can't distinguish vocabularies in the data. To
  # avoid misrepresenting what Episode actually emits, Episode overrides both
  # #vocabularies and #multiple_vocabularies to report no vocabularies. The
  # event-count introspection (events_per_patient) is unaffected — Episode
  # still produces multiple events per patient when its upstream does.
  describe 'introspection methods' do
    let(:db) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

    describe 'events_per_patient (Episode forwards to upstream)' do
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

      it 'forwards to upstream value identically' do
        upstream_query = db.query([:first, [:icd9, '250.00']])
        episode_query = db.query([:episode, [:first, [:icd9, '250.00']]])
        _(episode_query.events_per_patient).must_equal upstream_query.events_per_patient
      end
    end

    describe 'multiple_vocabularies (Episode strips vocab metadata)' do
      it 'returns false when upstream has a single vocabulary' do
        query = db.query([:episode, [:icd9, '250.00']])
        _(query.multiple_vocabularies).must_equal false
      end

      it 'returns false even when upstream is a union of multiple vocabularies' do
        query = db.query([:episode, [:union, [:icd9, '250.00'], [:cpt, '99214']]])
        _(query.multiple_vocabularies).must_equal false
      end
    end

    describe 'vocabularies (Episode strips vocab metadata)' do
      it 'returns [] regardless of upstream vocabulary IDs' do
        query = db.query([:episode, [:icd9, '250.00']])
        _(query.operator.vocabularies).must_equal []
      end

      it 'returns [] even when upstream is a union of multiple vocabularies' do
        query = db.query([:episode, [:union, [:icd9, '250.00'], [:cpt, '99214']]])
        _(query.operator.vocabularies).must_equal []
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
      describe "wrapped in #{op}" do
        let(:query) do
          db.query([op, [:episode, [:icd9, '250.00']], [:episode, [:cpt, '99214']], *opts])
        end

        it "#{op}#multiple_vocabularies returns false because Episodes report no vocabularies" do
          _(query.multiple_vocabularies).must_equal false
        end

        it "#{op}#vocabularies returns [] because Episodes strip vocabulary metadata" do
          _(query.operator.vocabularies).must_equal []
        end
      end
    end

    describe 'wrapped in concurrent_within' do
      let(:query) do
        db.query([:concurrent_within, [:episode, [:icd9, '250.00']], [:episode, [:cpt, '99214']],
                  { 'within' => '0d' }])
      end

      it 'concurrent_within#multiple_vocabularies returns false because Episodes report no vocabularies' do
        _(query.multiple_vocabularies).must_equal false
      end

      it 'concurrent_within#vocabularies returns [] because Episodes strip vocabulary metadata' do
        _(query.operator.vocabularies).must_equal []
      end
    end

    # Anchor: bare vocabulary (no Episode wrapper) must not be affected by the
    # Episode override.
    describe 'anchors (must NOT be affected by Episode override)' do
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

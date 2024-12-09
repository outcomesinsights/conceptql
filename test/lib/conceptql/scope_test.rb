require_relative '../../helper'

describe ConceptQL::Scope do
  describe 'using postgres' do
    let(:host) { :postgres }

    describe 'with a table_prefix' do
      let(:opts) do
        { scope_opts: { table_prefix: 'jtemp123456' } }
      end

      it 'should use prefix in table name' do
        if ENV['CONCEPTQL_AVOID_CTES'] == 'true'
          skip
        else
          db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm, force_temp_tables: true,
                                                                scratch_database: 'jigsaw_temp')
          _(db.query(['ADMSRCE', '12', { label: 'test label' }], opts).sql).must_match(/jtemp123456/)
        end
      end
    end

    describe 'with date literal windows' do
      let(:opts) do
        { scope_opts: { start_date: '2001-01-01', end_date: '2001-12-31' } }
      end

      it 'should limit selection by date range under gdm' do
        db = ConceptQL::Database.new(Sequel.mock(host: host), data_model: :gdm)
        cql_sql = db.query(%w[ADMSRCE 12], opts).sql
        assert_match(
          /WHERE \(\(CAST\('2001-01-01' AS date\) <= "start_date"\) AND \("start_date" <= CAST\('2001-12-31' AS date\)\)\)\)/, cql_sql
        )
      end
    end

    describe 'with windows from another table' do
      let(:opts) do
        { scope_opts: { window_table: :jtemp } }
      end

      it 'should limit selection by date range under gdm' do
        db = Sequel.mock(host: host)
        cdb = ConceptQL::Database.new(db, data_model: :gdm)
        db.add_table_schema(:jtemp, [[:person_id], [:start_date], [:end_date]])
        cql_sql = cdb.query(%w[ADMSRCE 12], opts).sql
        assert_match(/FROM "jtemp"/, cql_sql)
        assert_match(/"r"."start_date" <= "l"."start_date"/, cql_sql)
        assert_match(/"l"."start_date" <= "r"."end_date"/, cql_sql)
      end
    end

    describe 'with windows from another table, along with adjustments' do
      let(:opts) do
        { scope_opts: { window_table: :jtemp, adjust_window_start: '-30d', adjust_window_end: '1m' } }
      end

      it 'should limit selection by date range under gdm' do
        db = Sequel.mock(host: host)
        cdb = ConceptQL::Database.new(db, data_model: :gdm)
        db.add_table_schema(:jtemp, [[:person_id], [:start_date], [:end_date]])
        cql_sql = cdb.query(%w[ADMSRCE 12], opts).sql
        assert_match(/FROM "jtemp"/, cql_sql)
        assert_match(/make_interval\(days := -30\)/, cql_sql)
        assert_match(/make_interval\(months := 1\)/, cql_sql)
      end
    end
  end
end

# frozen_string_literal: true

require 'digest'
require_relative '../../db_helper'

# The statements of one Database share each hospitalization (Utilizable) list
# when the Database has the share_utilization option (bead conceptql-98p,
# seed conceptql-873).
describe 'ConceptQL::Database share_utilization' do
  prefix = "jtest98p#{Process.pid}"
  table_pattern = /"#{prefix}_util_\h{16}"/

  def share_opts(prefix)
    { share_utilization: true, scope_opts: { table_prefix: prefix } }
  end

  def mock_cdb(data_model, opts = {})
    ConceptQL::Database.new(Sequel.mock(host: :postgres), opts.merge(data_model: data_model))
  end

  %i[gdm gdm_wide].each do |data_model|
    it "reads the list from the shared table in #{data_model}" do
      cdb = mock_cdb(data_model, share_opts(prefix))
      query = cdb.query(['hospitalization'])
      op = query.operator
      key = op.select_it(op.query(cdb.db)).sql

      sql = query.sql

      _(sql).must_include %(FROM "#{prefix}_util_#{Digest::MD5.hexdigest(key)[0, 16]}")
      _(sql).wont_match(/"(observations|admission_details)"/)
      _(sql).wont_include 'WITH'
    end

    it "builds the list inline without the option in #{data_model}" do
      sql = mock_cdb(data_model).query(['hospitalization']).sql

      _(sql).wont_match table_pattern
      _(sql).must_match(/"(observations|admission_details)"/)
    end
  end

  it 'refuses the option without a table_prefix' do
    cdb = mock_cdb(:gdm_wide, share_utilization: true)

    _ { cdb.query(['hospitalization']) }.must_raise ArgumentError
  end

  describe 'on the test data' do
    before do
      skip 'not tried on Spark' if DB.database_type.to_sym == :spark
      @cdbs = []
    end

    after do
      @cdbs&.each { |cdb| DB.drop_table?(*cdb.shared_tables) unless cdb.shared_tables.empty? }
    end

    # cache_lookups keeps the lookup id lists in the list's SQL in one order,
    # as in CDB. Without it, DuckDB can return them in another order for
    # each statement, and each order is another key.
    def shared_cdb(prefix)
      opts = share_opts(prefix).merge(data_model: CDB.opts[:data_model], cache_lookups: true)
      ConceptQL::Database.new(DB, opts).tap { |cdb| @cdbs << cdb }
    end

    def rows(cdb, statement)
      cdb.query(statement).query.all.sort_by(&:to_s)
    end

    statements = [['hospitalization'], ['occurrence', 1, ['hospitalization']]]

    it 'returns the same rows as the inline list from one table' do
      cdb = shared_cdb(prefix)

      statements.each do |statement|
        expected = rows(CDB, statement)

        _(expected).wont_be_empty
        _(rows(cdb, statement)).must_equal expected
      end
      _(cdb.shared_tables.length).must_equal 1
      _(DB[cdb.shared_tables.first].count).must_be :>, 0
    end

    it 'creates no table to build SQL' do
      cdb = shared_cdb(prefix)
      query = cdb.query(statements.last)

      name = query.sql[table_pattern].delete('"').to_sym
      query.sql_statements
      query.annotate(skip_counts: true)

      _(cdb.shared_tables).must_be_empty
      _(DB.table_exists?(name)).must_equal false
    end

    it 'creates one table for each window' do
      cdb = shared_cdb(prefix)

      [%w[2008-01-01 2008-12-31], %w[2009-01-01 2010-12-31]].each do |start_date, end_date|
        rows(cdb, ['window', ['hospitalization'], { start_date: start_date, end_date: end_date }])
      end

      _(cdb.shared_tables.uniq.length).must_equal 2
    end
  end
end

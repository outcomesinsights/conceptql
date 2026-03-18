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
end

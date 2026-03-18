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
end

# frozen_string_literal: true

require_relative '../../../db_helper'
require 'conceptql/rdbms/duckdb'

describe ConceptQL::Rdbms::DuckDB do
  let(:db) { Sequel.mock(host: :duckdb) }
  let(:rdbms) { ConceptQL::Rdbms::DuckDB.new }

  describe '#days_between' do
    it 'uses subtraction between two dates' do
      result = db.literal(rdbms.days_between('2001-01-01', :date_column))

      _(result).must_match('"date_column"')
      _(result).must_match("CAST('2001-01-01' AS date)")
      _(result).must_match('-')
    end
  end

  describe '#primary_concepts' do
    it 'uses row_number instead of distinct on' do
      result = rdbms.primary_concepts(db, [1, 2]).sql

      _(result).must_match(/ROW_NUMBER\(\) OVER/i)
      _(result).wont_match(/DISTINCT ON/i)
      _(result).must_match(/WHERE \("nummy" = 1\)/i)
    end
  end
end

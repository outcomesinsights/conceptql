# frozen_string_literal: true

require_relative '../../../db_helper'

describe ConceptQL::Operators::From do
  it 'should handle QualifiedIdentifiers' do
    DB.create_view(:test_from_table, CDB.query(%w[icd9 412]).query, replace: true, temp: true)

    qi = Sequel.qualify(:test_from_schema, :test_from_table)
    stmt = [:after, {
      left: [:ndc, '012345678'],
      right: [:from, qi, { query_cols: ConceptQL::Scope::DEFAULT_COLUMNS.keys }]
    }]

    sql = CDB.query(stmt).sql
    _(sql).must_match(/test_from_schema/)
    _(sql).must_match(/test_from_table/)
  end
end

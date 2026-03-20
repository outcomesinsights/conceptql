# frozen_string_literal: true

require_relative '../../helper'
require 'conceptql/rdbms'

describe ConceptQL::Rdbms do
  describe '.generate' do
    it 'returns the DuckDB adapter for duckdb database type' do
      _(ConceptQL::Rdbms.generate(:duckdb)).must_be_instance_of(ConceptQL::Rdbms::DuckDB)
    end
  end
end

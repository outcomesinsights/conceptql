# frozen_string_literal: true

require_relative '../../helper'
require 'conceptql/rdbms'

describe ConceptQL::Rdbms do
  describe '.generate' do
    it 'returns the DuckDB adapter for duckdb database type' do
      Sequelizer::OptionalAdapterSupport.stub(:require_adapter!, nil) do
        _(ConceptQL::Rdbms.generate(:duckdb)).must_be_instance_of(ConceptQL::Rdbms::DuckDB)
      end
    end

    it 'raises a clear error when duckdb gems are unavailable' do
      Sequelizer::OptionalAdapterSupport.stub(
        :require_adapter!,
        ->(*) { raise Sequelizer::MissingOptionalAdapterError, 'duckdb support requires optional gems' },
      ) do
        error = _ { ConceptQL::Rdbms.generate(:duckdb) }.must_raise(Sequelizer::MissingOptionalAdapterError)

        _(error.message).must_match(/duckdb support requires optional gems/i)
      end
    end
  end
end

require 'spec_helper'
require 'conceptql/operators/from'
require_relative 'query_double'

describe ConceptQL::Operators::From do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'works for single criteria' do
      expect(ConceptQL::Operators::From.new(:table1).query(Sequel.mock).sql).to eq("SELECT * FROM table1")
    end
  end
end

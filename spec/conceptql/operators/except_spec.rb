require 'spec_helper'
require 'conceptql/operators/except'
require_relative 'query_double'

describe ConceptQL::Operators::Except do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'uses right stream as argument to EXCEPT against left stream' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      expect(ConceptQL::Operators::Except.new(left: double1, right: double2).query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT * FROM table1 EXCEPT SELECT * FROM table2) AS t1")
    end
  end
end

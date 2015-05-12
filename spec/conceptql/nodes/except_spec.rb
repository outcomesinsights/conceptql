require 'spec_helper'
require 'conceptql/operators/except'
require_relative 'query_double'

describe ConceptQL::Operators::Except do
  it 'behaves itself' do
    ConceptQL::Operators::Except.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'uses right stream as argument to EXCEPT against left stream' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      double1.must_behave_like(:evaluator)
      ConceptQL::Operators::Except.new(left: double1, right: double2).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM table1 EXCEPT SELECT * FROM table2) AS t1"
    end
  end
end

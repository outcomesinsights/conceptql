require 'spec_helper'
require 'conceptql/operators/union'
require_relative 'query_double'

describe ConceptQL::Operators::Union do
  it 'behaves itself' do
    ConceptQL::Operators::Union.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for multiple criteria' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      double3 = QueryDouble.new(3)
      double1.must_behave_like(:evaluator)
      ConceptQL::Operators::Union.new(double1, double2, double3).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM table1) AS t1 UNION ALL SELECT * FROM (SELECT * FROM table2) AS t1) AS t1 UNION ALL SELECT * FROM (SELECT * FROM table3) AS t1) AS t1"
    end

    it 'works for single criteria' do
      double1 = QueryDouble.new(1)
      double1.must_behave_like(:evaluator)
      ConceptQL::Operators::Union.new(double1).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM table1) AS t1"
    end
  end
end

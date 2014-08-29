require 'spec_helper'
require 'conceptql/nodes/intersect'
require_relative 'query_double'

describe ConceptQL::Nodes::Intersect do
  it 'behaves itself' do
    ConceptQL::Nodes::Intersect.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for multiple criteria of same type' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      double3 = QueryDouble.new(3)
      double1.must_behave_like(:evaluator)
      ConceptQL::Nodes::Intersect.new(double1, double2, double3).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM table1 INTERSECT SELECT * FROM table2) AS t1 INTERSECT SELECT * FROM table3) AS t1"
    end

    it 'works for multiple criteria of different type' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2, :person)
      double3 = QueryDouble.new(3)
      double1.must_behave_like(:evaluator)
      ConceptQL::Nodes::Intersect.new(double1, double2, double3).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM (SELECT * FROM table1 INTERSECT SELECT * FROM table3) AS t1 UNION ALL SELECT * FROM table2) AS t1"
    end

    it 'works for single criteria' do
      double1 = QueryDouble.new(1)
      double1.must_behave_like(:evaluator)
      ConceptQL::Nodes::Intersect.new(double1).query(Sequel.mock).sql.must_equal "SELECT * FROM table1"
    end
  end
end

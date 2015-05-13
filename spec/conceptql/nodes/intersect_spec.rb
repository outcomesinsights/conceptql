require 'spec_helper'
require 'conceptql/operators/intersect'
require_relative 'query_double'

describe ConceptQL::Operators::Intersect do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'works for multiple criteria of same type' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      double3 = QueryDouble.new(3)
      expect(ConceptQL::Operators::Intersect.new(double1, double2, double3).query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT * FROM (SELECT * FROM table1 INTERSECT SELECT * FROM table2) AS t1 INTERSECT SELECT * FROM table3) AS t1")
    end

    it 'works for multiple criteria of different type' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2, :person)
      double3 = QueryDouble.new(3)
      expect(ConceptQL::Operators::Intersect.new(double1, double2, double3).query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT * FROM (SELECT * FROM table1 INTERSECT SELECT * FROM table3) AS t1 UNION ALL SELECT * FROM table2) AS t1")
    end

    it 'works for single criteria' do
      double1 = QueryDouble.new(1)
      expect(ConceptQL::Operators::Intersect.new(double1).query(Sequel.mock).sql).to eq("SELECT * FROM table1")
    end
  end
end

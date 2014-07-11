require 'spec_helper'
require 'conceptql/nodes/person_filter'
require_relative 'query_double'

describe ConceptQL::Nodes::PersonFilter do
  it 'behaves itself' do
    ConceptQL::Nodes::PersonFilter.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'uses right stream as argument to PERSON_FILTER against left stream' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      double1.must_behave_like(:evaluator)
      ConceptQL::Nodes::PersonFilter.new(left: double1, right: double2).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT * FROM table1) AS t1 WHERE (person_id IN (SELECT person_id FROM table2 GROUP BY person_id))"
    end
  end
end

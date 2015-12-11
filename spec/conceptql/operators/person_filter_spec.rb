require 'spec_helper'
require 'conceptql/operators/person_filter'
require_relative 'query_double'

describe ConceptQL::Operators::PersonFilter do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'uses right stream as argument to PERSON_FILTER against left stream' do
      double1 = QueryDouble.new(1)
      double2 = QueryDouble.new(2)
      expect(ConceptQL::Operators::PersonFilter.new(left: double1, right: double2).query(Sequel.mock).sql).to eq("SELECT * FROM (SELECT * FROM table1) AS t1 WHERE (person_id IN (SELECT person_id FROM table2 GROUP BY person_id))")
    end
  end
end

require 'spec_helper'
require 'conceptql/operators/complement'
require_relative 'query_double'

describe ConceptQL::Operators::Complement do
  it_behaves_like(:evaluator)

  it 'generates complement for single criteria' do
    double1 = QueryDouble.new(1)
    sql = ConceptQL::Operators::Complement.new(double1).query(Sequel.mock).sql
    expect(sql).to match("criterion_id IS NOT NULL")
    expect(sql).to match("visit_occurrence_id NOT IN")
    expect(sql).to match("criterion_type = 'visit_occurrence'")
  end
end

require 'spec_helper'
require 'conceptql/nodes/complement'
require_relative 'query_double'

describe ConceptQL::Operators::Complement do
  it 'behaves itself' do
    ConceptQL::Operators::Complement.new.must_behave_like(:evaluator)
  end

  it 'generates complement for single criteria' do
    double1 = QueryDouble.new(1)
    double1.must_behave_like(:evaluator)
    sql = ConceptQL::Operators::Complement.new(double1).query(Sequel.mock).sql
    sql.must_match "criterion_id IS NOT NULL"
    sql.must_match "visit_occurrence_id NOT IN"
    sql.must_match "criterion_type = 'visit_occurrence'"
  end
end

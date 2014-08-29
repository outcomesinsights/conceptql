require 'spec_helper'
require 'conceptql/nodes/complement'
require_relative 'query_double'

describe ConceptQL::Nodes::Complement do
  it 'behaves itself' do
    ConceptQL::Nodes::Complement.new.must_behave_like(:evaluator)
  end

  it 'generates complement for single criteria' do
    double1 = QueryDouble.new(1)
    double1.must_behave_like(:evaluator)
    ConceptQL::Nodes::Complement.new(double1).query(Sequel.mock).sql.must_equal "SELECT * FROM (SELECT person_id AS person_id, visit_occurrence_id AS criterion_id, CAST('visit_occurrence' AS varchar(255)) AS criterion_type, CAST(visit_start_date AS date) AS start_date, CAST(visit_end_date AS date) AS end_date FROM visit_occurrence AS tab WHERE (visit_occurrence_id NOT IN (SELECT criterion_id FROM (SELECT * FROM table1) AS t1 WHERE ((criterion_id IS NOT NULL) AND (criterion_type = 'visit_occurrence'))))) AS t1"
  end
end

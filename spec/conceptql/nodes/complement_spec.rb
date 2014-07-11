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
    ConceptQL::Nodes::Complement.new(double1).query(Sequel.mock).sql.must_equal "SELECT person_id AS person_id, CAST(NULL AS bigint) AS condition_occurrence_id, CAST(NULL AS bigint) AS death_id, CAST(NULL AS bigint) AS drug_cost_id, CAST(NULL AS bigint) AS drug_exposure_id, CAST(NULL AS bigint) AS observation_id, CAST(NULL AS bigint) AS payer_plan_period_id, CAST(NULL AS bigint) AS procedure_cost_id, CAST(NULL AS bigint) AS procedure_occurrence_id, visit_occurrence_id AS visit_occurrence_id, start_date, end_date FROM visit_occurrence_with_dates AS tab WHERE (visit_occurrence_id NOT IN (SELECT * FROM (SELECT visit_occurrence_id FROM table1) AS t1 WHERE (visit_occurrence_id IS NOT NULL)))"
  end
end

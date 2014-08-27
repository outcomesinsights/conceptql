require 'spec_helper'
require 'conceptql/nodes/race'

describe ConceptQL::Nodes::Race do
  it 'behaves itself' do
    ConceptQL::Nodes::Race.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for white' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white'))"
      ConceptQL::Nodes::Race.new('White').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Race.new('white').query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for multiple values' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white', 'other'))"
      ConceptQL::Nodes::Race.new('White', 'Other').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Race.new('white', 'other').query(Sequel.mock).sql.must_equal correct_query
    end
  end
end


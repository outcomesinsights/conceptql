require 'spec_helper'
require 'conceptql/nodes/race'

describe ConceptQL::Operators::Race do
  it 'behaves itself' do
    ConceptQL::Operators::Race.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for white' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white'))"
      ConceptQL::Operators::Race.new('White').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Race.new('white').query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for multiple values' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white', 'other'))"
      ConceptQL::Operators::Race.new('White', 'Other').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Race.new('white', 'other').query(Sequel.mock).sql.must_equal correct_query
    end
  end
end


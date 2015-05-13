require 'spec_helper'
require 'conceptql/operators/race'

describe ConceptQL::Operators::Race do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'works for white' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white'))"
      expect(ConceptQL::Operators::Race.new('White').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Race.new('white').query(Sequel.mock).sql).to eq(correct_query)
    end

    it 'works for multiple values' do
      correct_query = "SELECT * FROM person AS p INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = p.race_concept_id) WHERE (lower(vc.concept_name) IN ('white', 'other'))"
      expect(ConceptQL::Operators::Race.new('White', 'Other').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Race.new('white', 'other').query(Sequel.mock).sql).to eq(correct_query)
    end
  end
end


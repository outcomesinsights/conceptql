require 'spec_helper'
require 'conceptql/nodes/place_of_service_code'

describe ConceptQL::Nodes::PlaceOfServiceCode do
  it 'behaves itself' do
    ConceptQL::Nodes::PlaceOfServiceCode.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for 23' do
      correct_query = "SELECT * FROM visit_occurrence_with_dates AS v INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = v.place_of_service_concept_id) WHERE (vc.concept_code IN ('23'))"
      ConceptQL::Nodes::PlaceOfServiceCode.new('23').query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for 23 as number' do
      correct_query = "SELECT * FROM visit_occurrence_with_dates AS v INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = v.place_of_service_concept_id) WHERE (vc.concept_code IN ('23'))"
      ConceptQL::Nodes::PlaceOfServiceCode.new(23).query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for multiple values' do
      correct_query = "SELECT * FROM visit_occurrence_with_dates AS v INNER JOIN vocabulary.concept AS vc ON (vc.concept_id = v.place_of_service_concept_id) WHERE (vc.concept_code IN ('23', '22'))"
      ConceptQL::Nodes::PlaceOfServiceCode.new('23', '22').query(Sequel.mock).sql.must_equal correct_query
    end
  end
end


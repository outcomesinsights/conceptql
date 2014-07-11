require 'spec_helper'
require 'conceptql/nodes/gender'

describe ConceptQL::Nodes::Gender do
  it 'behaves itself' do
    ConceptQL::Nodes::Gender.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for male/MALE/Male/M/m' do
      correct_query = "SELECT * FROM person_with_dates WHERE (gender_concept_id IN (8507))"
      ConceptQL::Nodes::Gender.new('male').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('Male').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('MALE').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('M').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('m').query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for Female/FEMALE/female/F/f' do
      correct_query = "SELECT * FROM person_with_dates WHERE (gender_concept_id IN (8532))"
      ConceptQL::Nodes::Gender.new('female').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('Female').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('FEMALE').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('F').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Nodes::Gender.new('f').query(Sequel.mock).sql.must_equal correct_query
    end
  end
end


require 'spec_helper'
require 'conceptql/nodes/gender'

describe ConceptQL::Operators::Gender do
  it 'behaves itself' do
    ConceptQL::Operators::Gender.new.must_behave_like(:evaluator)
  end

  describe '#query' do
    it 'works for male/MALE/Male/M/m' do
      correct_query = "SELECT * FROM person WHERE (gender_concept_id IN (8507))"
      ConceptQL::Operators::Gender.new('male').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('Male').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('MALE').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('M').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('m').query(Sequel.mock).sql.must_equal correct_query
    end

    it 'works for Female/FEMALE/female/F/f' do
      correct_query = "SELECT * FROM person WHERE (gender_concept_id IN (8532))"
      ConceptQL::Operators::Gender.new('female').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('Female').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('FEMALE').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('F').query(Sequel.mock).sql.must_equal correct_query
      ConceptQL::Operators::Gender.new('f').query(Sequel.mock).sql.must_equal correct_query
    end
  end
end


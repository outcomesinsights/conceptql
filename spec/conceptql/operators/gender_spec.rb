require 'spec_helper'
require 'conceptql/operators/gender'

describe ConceptQL::Operators::Gender do
  it_behaves_like(:evaluator)

  describe '#query' do
    it 'works for male/MALE/Male/M/m' do
      correct_query = "SELECT * FROM person WHERE (gender_concept_id IN (8507))"
      expect(ConceptQL::Operators::Gender.new('male').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('Male').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('MALE').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('M').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('m').query(Sequel.mock).sql).to eq(correct_query)
    end

    it 'works for Female/FEMALE/female/F/f' do
      correct_query = "SELECT * FROM person WHERE (gender_concept_id IN (8532))"
      expect(ConceptQL::Operators::Gender.new('female').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('Female').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('FEMALE').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('F').query(Sequel.mock).sql).to eq(correct_query)
      expect(ConceptQL::Operators::Gender.new('f').query(Sequel.mock).sql).to eq(correct_query)
    end
  end
end


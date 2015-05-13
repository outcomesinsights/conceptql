require 'spec_helper'
require 'conceptql/operators/standard_vocabulary_operator'

describe ConceptQL::Operators::StandardVocabularyOperator do
  it_behaves_like(:evaluator)

  class StandardVocabularyDouble < ConceptQL::Operators::StandardVocabularyOperator
    def table
      :table
    end

    def concept_column
      :concept_column
    end

    def vocabulary_id
      1
    end
  end

  describe StandardVocabularyDouble do
    it_behaves_like(:standard_vocabulary_operator)
  end

  describe '#query' do
    it 'works for single values' do
      expect(StandardVocabularyDouble.new('value').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.concept_column) WHERE ((c.concept_code IN ('value')) AND (c.vocabulary_id = 1))")
    end

    it 'works for multiple diagnoses' do
      expect(StandardVocabularyDouble.new('value1', 'value2').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.concept_column) WHERE ((c.concept_code IN ('value1', 'value2')) AND (c.vocabulary_id = 1))")
    end
  end
end


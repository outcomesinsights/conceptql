require 'spec_helper'
require 'conceptql/nodes/standard_vocabulary_node'

describe ConceptQL::Nodes::StandardVocabularyNode do
  it 'behaves itself' do
    ConceptQL::Nodes::StandardVocabularyNode.new.must_behave_like(:evaluator)
  end

  class StandardVocabularyDouble < ConceptQL::Nodes::StandardVocabularyNode
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
    it 'behaves itself' do
      StandardVocabularyDouble.new.must_behave_like(:standard_vocabulary_node)
    end
  end

  describe '#query' do
    it 'works for single values' do
      StandardVocabularyDouble.new('value').query(Sequel.mock).sql.must_equal "SELECT * FROM table_with_dates AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.concept_column) WHERE ((c.concept_code IN ('value')) AND (c.vocabulary_id = 1))"
    end

    it 'works for multiple diagnoses' do
      StandardVocabularyDouble.new('value1', 'value2').query(Sequel.mock).sql.must_equal "SELECT * FROM table_with_dates AS tab INNER JOIN vocabulary.concept AS c ON (c.concept_id = tab.concept_column) WHERE ((c.concept_code IN ('value1', 'value2')) AND (c.vocabulary_id = 1))"
    end
  end
end



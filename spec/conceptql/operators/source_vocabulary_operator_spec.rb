require 'spec_helper'
require 'conceptql/operators/source_vocabulary_operator'

describe ConceptQL::Operators::SourceVocabularyOperator do
  it_behaves_like(:evaluator)

  class SourceVocabularyDouble < ConceptQL::Operators::SourceVocabularyOperator
    def table
      :table
    end

    def source_column
      :source_column
    end

    def concept_column
      :concept_column
    end

    def vocabulary_id
      1
    end
  end

  describe '#query' do
    it 'works for single values' do
      expect(SourceVocabularyDouble.new('value').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON (scm.target_concept_id = tab.concept_column) WHERE ((scm.source_code IN ('value')) AND (scm.source_vocabulary_id = 1) AND (scm.source_code = tab.source_column))")
    end

    it 'works for multiple values' do
      expect(SourceVocabularyDouble.new('value1', 'value2').query(Sequel.mock).sql).to eq("SELECT * FROM table AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON (scm.target_concept_id = tab.concept_column) WHERE ((scm.source_code IN ('value1', 'value2')) AND (scm.source_vocabulary_id = 1) AND (scm.source_code = tab.source_column))")
    end
  end
end


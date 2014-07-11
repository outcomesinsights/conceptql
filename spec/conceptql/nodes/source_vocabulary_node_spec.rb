require 'spec_helper'
require 'conceptql/nodes/source_vocabulary_node'

describe ConceptQL::Nodes::SourceVocabularyNode do
  it 'behaves itself' do
    ConceptQL::Nodes::SourceVocabularyNode.new.must_behave_like(:evaluator)
  end

  class SourceVocabularyDouble < ConceptQL::Nodes::SourceVocabularyNode
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
      SourceVocabularyDouble.new('value').query(Sequel.mock).sql.must_equal "SELECT * FROM table_with_dates AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON (scm.target_concept_id = tab.concept_column) WHERE ((scm.source_code IN ('value')) AND (scm.source_vocabulary_id = 1) AND (scm.source_code = tab.source_column))"
    end

    it 'works for multiple values' do
      SourceVocabularyDouble.new('value1', 'value2').query(Sequel.mock).sql.must_equal "SELECT * FROM table_with_dates AS tab INNER JOIN vocabulary.source_to_concept_map AS scm ON (scm.target_concept_id = tab.concept_column) WHERE ((scm.source_code IN ('value1', 'value2')) AND (scm.source_vocabulary_id = 1) AND (scm.source_code = tab.source_column))"
    end
  end
end


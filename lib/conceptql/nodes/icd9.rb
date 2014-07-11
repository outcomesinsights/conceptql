require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class Icd9 < SourceVocabularyNode
      def table
        :condition_occurrence
      end

      def vocabulary_id
        2
      end

      def source_column
        :condition_source_value
      end

      def concept_column
        :condition_concept_id
      end
    end
  end
end

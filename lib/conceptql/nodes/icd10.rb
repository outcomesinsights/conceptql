require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class Icd10 < SourceVocabularyNode
      def table
        :condition_occurrence
      end

      def vocabulary_id
        34
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

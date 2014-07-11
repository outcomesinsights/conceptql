require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Icd9Procedure < StandardVocabularyNode
      def table
        :procedure_occurrence
      end

      def vocabulary_id
        3
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end


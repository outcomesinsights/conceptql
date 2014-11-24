require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class SnomedCondition < StandardVocabularyNode
      def table
        :condition_occurrence
      end

      def vocabulary_id
        1
      end

      def concept_column
        :condition_concept_id
      end
    end
  end
end



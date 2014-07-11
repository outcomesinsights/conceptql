require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Cpt < StandardVocabularyNode
      def table
        :procedure_occurrence
      end

      def vocabulary_id
        4
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end


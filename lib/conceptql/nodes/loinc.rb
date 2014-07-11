require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Loinc < StandardVocabularyNode
      def table
        :observation
      end

      def vocabulary_id
        6
      end

      def concept_column
        :observation_concept_id
      end
    end
  end
end


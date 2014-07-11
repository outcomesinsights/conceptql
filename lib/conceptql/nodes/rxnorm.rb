require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Rxnorm < StandardVocabularyNode
      def table
        :drug_exposure
      end

      def vocabulary_id
        8
      end

      def concept_column
        :drug_concept_id
      end
    end
  end
end


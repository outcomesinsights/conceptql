require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class Ndc < SourceVocabularyNode
      def table
        :drug_exposure
      end

      def vocabulary_id
        9
      end

      def source_column
        :drug_source_value
      end

      def concept_column
        :drug_concept_id
      end
    end
  end
end


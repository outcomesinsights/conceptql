require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class ObservationByEnttype < SourceVocabularyNode
      def table
        :observation
      end

      def vocabulary_id
        [206, 207]
      end

      def source_column
        :observation_source_value
      end

      def concept_column
        :observation_concept_id
      end
    end
  end
end



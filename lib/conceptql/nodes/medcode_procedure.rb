require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class MedcodeProcedure < SourceVocabularyNode
      def table
        :procedure_occurrence
      end

      def vocabulary_id
        204
      end

      def source_column
        :procedure_source_value
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end

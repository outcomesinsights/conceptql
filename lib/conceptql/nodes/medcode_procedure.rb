require_relative 'source_vocabulary_node'

module ConceptQL
  module Nodes
    class MedcodeProcedure < SourceVocabularyNode
      desc 'Searches the procedure_occurrence table for all procedures with matching Medcodes'
      argument :medcodes, type: :codelist, vocab: '204'
      predominant_types :procedure_occurrence

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

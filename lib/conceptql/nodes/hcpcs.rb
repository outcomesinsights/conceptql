require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Hcpcs < StandardVocabularyNode
      preferred_name 'HCPCS'
      desc 'Searches the procedure_occurrence table for all procedures with matching HCPCS codes'
      argument :hcpcs, type: :codelist, vocab: 'HCPCS'
      predominant_types :procedure_occurrence

      def table
        :procedure_occurrence
      end

      def vocabulary_id
        5
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end


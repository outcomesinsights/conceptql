require_relative 'standard_vocabulary_node'

module ConceptQL
  module Nodes
    class Cpt < StandardVocabularyNode
      preferred_name 'CPT'
      desc 'Searches the procedure_occurrence table for all procedures with matching CPT codes'
      argument :cpts, type: :codelist, vocab: 'CPT4'

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


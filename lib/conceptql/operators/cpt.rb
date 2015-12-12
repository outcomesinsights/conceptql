require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Cpt < StandardVocabularyOperator
      register __FILE__

      preferred_name 'CPT'
      desc 'Searches the procedure_occurrence table for all procedures with matching CPT codes'
      argument :cpts, type: :codelist, vocab: 'CPT4'
      predominant_types :procedure_occurrence

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


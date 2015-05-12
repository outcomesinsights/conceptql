require_relative 'standard_vocabulary_node'

module ConceptQL
  module Operators
    class Icd9Procedure < StandardVocabularyOperator
      preferred_name 'ICD-9 Proc'
      desc 'Searches the procedure_occurrence table for the given set of ICD-9 codes.'
      argument :icd9s, type: :codelist, vocab: 'ICD9Proc'
      predominant_types :procedure_occurrence

      def table
        :procedure_occurrence
      end

      def vocabulary_id
        3
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end


require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd9Procedure < StandardVocabularyOperator
      register __FILE__

      preferred_name 'ICD-9 Proc'
      argument :icd9s, type: :codelist, vocab: 'ICD9Proc'
      predominant_domains :procedure_occurrence

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


require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd10Pcs < StandardVocabularyOperator
      register __FILE__

      preferred_name 'ICD-10 PCS'
      argument :icd10s, type: :codelist, vocab: 'ICD10PCS'
      predominant_domains :procedure_occurrence

      codes_should_match(/^[A-HJ-NP-Z\d]{7}$/i)

      def table
        :procedure_occurrence
      end

      def vocabulary_id
        35
      end

      def concept_column
        :procedure_concept_id
      end
    end
  end
end


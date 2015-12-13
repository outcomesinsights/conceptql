require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd10 < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__

      preferred_name 'ICD-10 CM'
      desc 'Searches the condition_occurrence table for the given set of ICD-10 codes.'
      argument :icd10s, type: :codelist, vocab: 'ICD10CM'
      predominant_types :condition_occurrence

      def vocabulary_id
        34
      end
    end
  end
end

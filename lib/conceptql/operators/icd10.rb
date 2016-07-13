require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd10 < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__

      preferred_name 'ICD-10 CM'
      argument :icd10s, type: :codelist, vocab: 'ICD10CM'
      predominant_domains :condition_occurrence

      codes_should_match(/^[A-Z][0-9][A-Z0-9](\.[A-Z0-9]{1,4})?$/i)

      def vocabulary_id
        34
      end
    end
  end
end

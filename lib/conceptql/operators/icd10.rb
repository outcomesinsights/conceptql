require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd10 < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__, :omopv4

      preferred_name 'ICD-10 CM'
      argument :icd10s, type: :codelist, vocab: 'ICD10CM'
      predominant_domains :condition_occurrence

      def vocabulary_id
        34
      end
    end
  end
end

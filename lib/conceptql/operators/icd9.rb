require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd9 < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__, :omopv4

      preferred_name 'ICD-9-CM'
      argument :icd9s, type: :codelist, vocab: 'ICD9CM'
      predominant_domains :condition_occurrence

      def vocabulary_id
        2
      end
    end
  end
end

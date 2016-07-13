require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Icd9 < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__

      preferred_name 'ICD-9 CM'
      argument :icd9s, type: :codelist, vocab: 'ICD9CM'
      predominant_domains :condition_occurrence

      codes_should_match(/^(V\d{2}(\.\d{1,2})?|\d{3}(\.\d{1,2})?|E\d{3}(\.\d)?)$/i)

      def vocabulary_id
        2
      end
    end
  end
end

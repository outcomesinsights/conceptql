require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Read < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__, :omopv4

      preferred_name "READ"
      argument :read_codes, type: :codelist, vocab: "Read"
      predominant_domains :condition_occurrence

      def vocabulary_id
        17
      end
    end
  end
end

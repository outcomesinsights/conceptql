require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Read < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__, :omopv4

      preferred_name "READ"
      desc "Searches the condition_occurrence table for the given set of READ codes."
      argument :read_codess, type: :codelist, vocab: "Read"
      predominant_domains :condition_occurrence

      def vocabulary_id
        17
      end
    end
  end
end

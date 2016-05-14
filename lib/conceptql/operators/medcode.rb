require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Medcode < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__, :omopv4

      argument :medcodes, type: :codelist, vocab_id: '203'
      predominant_domains :condition_occurrence

      def vocabulary_id
        203
      end
    end
  end
end


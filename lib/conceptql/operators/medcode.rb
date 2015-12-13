require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class Medcode < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__

      desc 'Searches the condition_occurrence table for all conditions with matching Medcodes'
      argument :medcodes, type: :codelist, vocab_id: '203'
      predominant_types :condition_occurrence

      def vocabulary_id
        203
      end
    end
  end
end


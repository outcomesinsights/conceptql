require_relative 'source_vocabulary_operator'

module ConceptQL
  module Operators
    class ConditionOccurrenceSourceVocabularyOperator < SourceVocabularyOperator
      def unionable?(other)
        other.is_a?(ConditionOccurrenceSourceVocabularyOperator)
      end

      def union(other)
        if other.is_a?(self.class)
          dup_values(values + other.values)
        elsif other.is_a?(ConditionOccurrenceSourceVocabularyOperatorUnion)
          other.union(self)
        else
          ConditionOccurrenceSourceVocabularyOperatorUnion.new(self, other)
        end
      end

      def table
        :condition_occurrence
      end

      def source_column
        :condition_source_value
      end

      def concept_column
        :condition_concept_id
      end
    end
  end
end


require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class ConditionOccurrenceSourceVocabularyOperatorUnion < ConditionOccurrenceSourceVocabularyOperator
      def union(other)
        if other.is_a?(self.class)
          dup_values(values + other.values)
        else
          same, different = values.partition{|x| x.is_a?(other.class)}
          case same.length
          when 0
            dup_values(different + [other])
          when 1
            dup_values(different + [same.first.union(other)])
          else
            raise "multiple ConditionOccurrenceSourceVocabularyOperator subclass instances of same class in union"
          end
        end
      end

      def conditions(db)
        Sequel.|(*values.map { |v| v.conditions(db) })
      end
    end
  end
end


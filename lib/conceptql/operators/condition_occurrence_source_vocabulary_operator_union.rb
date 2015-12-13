require_relative 'condition_occurrence_source_vocabulary_operator'

module ConceptQL
  module Operators
    class ConditionOccurrenceSourceVocabularyOperatorUnion < ConditionOccurrenceSourceVocabularyOperator
      register __FILE__

      #preferred_name ''
      desc 'Searches the condition_occurrence table based on a union of multiple source vocabulary operators.'
      #argument :source_vocabulary_operators, type: :codelist, vocab: ''
      predominant_types :condition_occurrence

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

      def conditions
        Sequel.|(*values.map(&:conditions))
      end
    end
  end
end


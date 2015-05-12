require_relative 'source_vocabulary_node'

module ConceptQL
  module Operators
    class Medcode < SourceVocabularyNode
      desc 'Searches the condition_occurrence table for all conditions with matching Medcodes'
      argument :medcodes, type: :codelist, vocab_id: '203'
      predominant_types :condition_occurrence

      def table
        :condition_occurrence
      end

      def vocabulary_id
        203
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


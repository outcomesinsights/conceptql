require_relative 'source_vocabulary_operator'

module ConceptQL
  module Operators
    class ObservationByEnttype < SourceVocabularyOperator
      register __FILE__, :omopv4

      desc 'Searches the observation table for all observations with matching Enttype'
      argument :enttypes, type: :codelist, vocab_id: [206, 207]
      predominant_domains :observation

      def table
        :observation
      end

      def vocabulary_id
        [206, 207]
      end

      def source_column
        :observation_source_value
      end

      def concept_column
        :observation_concept_id
      end
    end
  end
end



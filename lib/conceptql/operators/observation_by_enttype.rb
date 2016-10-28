require_relative 'source_vocabulary_operator'

module ConceptQL
  module Operators
    class ObservationByEnttype < SourceVocabularyOperator
      register __FILE__

      argument :enttypes, type: :codelist, vocab_id: [206, 207]
      predominant_domains :observation
      require_column :value_as_number
      require_column :value_as_string
      require_column :value_as_concept_id
      require_column :units_source_value
      require_column :range_low
      require_column :range_high

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



require_relative 'source_vocabulary_operator'
require_relative '../behaviors/labish'

module ConceptQL
  module Operators
    class ObservationByEnttype < SourceVocabularyOperator
      register __FILE__

      argument :enttypes, type: :codelist, vocab_id: [206, 207]
      predominant_domains :observation
      include ConceptQL::Labish

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



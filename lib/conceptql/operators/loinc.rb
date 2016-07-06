require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Loinc < StandardVocabularyOperator
      register __FILE__

      preferred_name 'LOINC'
      argument :loincs, type: :codelist, vocab: 'LOINC'
      predominant_domains :observation

      def table
        :observation
      end

      def vocabulary_id
        6
      end

      def concept_column
        :observation_concept_id
      end
    end
  end
end


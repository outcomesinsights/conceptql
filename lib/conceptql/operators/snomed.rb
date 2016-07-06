require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Snomed < StandardVocabularyOperator
      register __FILE__

      preferred_name 'SNOMED'
      argument :snomeds, type: :codelist, vocab: 'SNOMED'
      predominant_domains :condition_occurrence

      def table
        :condition_occurrence
      end

      def vocabulary_id
        1
      end

      def concept_column
        :condition_concept_id
      end
    end
  end
end

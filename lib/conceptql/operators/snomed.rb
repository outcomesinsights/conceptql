require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Snomed < StandardVocabularyOperator
      register __FILE__, :omopv4
      register __FILE__.sub("snomed", "snomed_condition"), :omopv4

      preferred_name 'SNOMED'
      desc 'Find all condition_occurrences by SNOMED codes'
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

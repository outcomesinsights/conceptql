require_relative 'source_vocabulary_node'

module ConceptQL
  module Operators
    class Icd10 < SourceVocabularyOperator
      preferred_name 'ICD-10 CM'
      desc 'Searches the condition_occurrence table for the given set of ICD-10 codes.'
      argument :icd10s, type: :codelist, vocab: 'ICD10CM'
      predominant_types :condition_occurrence

      def table
        :condition_occurrence
      end

      def vocabulary_id
        34
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

require_relative 'source_vocabulary_node'

module ConceptQL
  module Operators
    class Icd9 < SourceVocabularyNode
      preferred_name 'ICD-9 CM'
      desc 'Searches the condition_occurrence table for the given set of ICD-9 codes.'
      argument :icd9s, type: :codelist, vocab: 'ICD9CM'
      predominant_types :condition_occurrence

      def table
        :condition_occurrence
      end

      def vocabulary_id
        2
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

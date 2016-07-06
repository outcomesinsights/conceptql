require_relative 'source_vocabulary_operator'

module ConceptQL
  module Operators
    class Ndc < SourceVocabularyOperator
      register __FILE__

      preferred_name 'NDC'
      argument :ndcs, type: :codelist, vocab: 'NDC'
      predominant_domains :drug_exposure

      def table
        :drug_exposure
      end

      def vocabulary_id
        9
      end

      def source_column
        :drug_source_value
      end

      def concept_column
        :drug_concept_id
      end
    end
  end
end


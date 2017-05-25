require_relative 'source_vocabulary_operator'
require_relative '../behaviors/drugish'

module ConceptQL
  module Operators
    class Gemscript < SourceVocabularyOperator
      register __FILE__

      preferred_name 'Gemscript'
      argument :ndcs, type: :codelist, vocab: 'Gemscript'
      predominant_domains :drug_exposure
      codes_should_match(/^\d{8}$/)
      include ConceptQL::Drugish

      def table
        :drug_exposure
      end

      def vocabulary_id
        56
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


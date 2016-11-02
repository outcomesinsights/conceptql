require_relative 'standard_vocabulary_operator'
require_relative '../behaviors/drugish'

module ConceptQL
  module Operators
    class Rxnorm < StandardVocabularyOperator
      register __FILE__

      preferred_name 'RxNorm'
      argument :rxnorms, type: :codelist, vocab: 'RxNorm'
      predominant_domains :drug_exposure
      include ConceptQL::Drugish

      def table
        :drug_exposure
      end

      def vocabulary_id
        8
      end

      def concept_column
        :drug_concept_id
      end
    end
  end
end


require_relative 'standard_vocabulary_node'

module ConceptQL
  module Operators
    class Rxnorm < StandardVocabularyNode
      preferred_name 'RxNorm'
      desc 'Finds all drug_exposures by RxNorm codes'
      argument :rxnorms, type: :codelist, vocab: 'RxNorm'

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


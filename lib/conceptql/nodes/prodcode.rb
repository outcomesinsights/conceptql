require_relative 'source_vocabulary_node'

module ConceptQL
  module Operators
    class Prodcode < SourceVocabularyNode
      desc 'Searches the drug_exposure table for all conditions with matching Prodcodes'
      argument :prodcodes, type: :codelist, vocab_id: '203'
      predominant_types :drug_exposure

      def table
        :drug_exposure
      end

      def vocabulary_id
        200
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



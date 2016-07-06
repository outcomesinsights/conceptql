require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Drg < StandardVocabularyOperator
      register __FILE__

      preferred_name "DRG"
      argument :drgs, type: :codelist, vocab: 'DRG'
      predominant_domains :procedure_occurrence

      def query(db)
        costs = super(db).select(:procedure_occurrence_id)
        db[:procedure_occurrence].where(procedure_occurrence_id: costs)
      end

      def domain
        :procedure_occurrence
      end

      def table
        :procedure_cost
      end

      def vocabulary_id
        40
      end

      def concept_column
        :disease_class_concept_id
      end

      def code_column
        :disease_class_source_value
      end
    end
  end
end



require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Drg < StandardVocabularyOperator
      register __FILE__, :omopv4

      desc 'Searches the procedure_occurrence table for all procedures that have an associated procedure_cost record with matching DRG codes'
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
    end
  end
end



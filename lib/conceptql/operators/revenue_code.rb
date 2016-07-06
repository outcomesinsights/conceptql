require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class RevenueCode < StandardVocabularyOperator
      register __FILE__

      desc 'Searches the procedure_occurrence table for all procedures that have an associated procedure_cost record with matching revenue codes'
      argument :revenue_codes, type: :codelist, vocab: 'Revenue Code'
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
        43
      end

      def code_column
        :revenue_code_source_value
      end
    end
  end
end



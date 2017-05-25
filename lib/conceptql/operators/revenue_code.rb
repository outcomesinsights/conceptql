require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class RevenueCode < StandardVocabularyOperator
      register __FILE__

      desc 'Searches the procedure_occurrence table for all procedures that have an associated procedure_cost record with matching revenue codes'
      argument :revenue_codes, type: :codelist, vocab: 'Revenue Code'
      predominant_domains :procedure_occurrence

      def query(db)
        if oi_cdm?
          vocab_op.query(db)
        else
          costs = super(db).select(:procedure_occurrence_id)
          db[:procedure_occurrence].where(procedure_occurrence_id: costs)
        end
      end

      def query_cols
        table_columns(:procedure_occurrence, :concept)
      end

      def domain
        :procedure_occurrence
      end

      def table
        if oi_cdm?
          vocab_op.table
        else
          :procedure_cost
        end
      end

      def vocabulary_id
        43
      end

      def concept_column
        :revenue_code_concept_id
      end

      def code_column
        :revenue_code_source_value
      end
    end
  end
end



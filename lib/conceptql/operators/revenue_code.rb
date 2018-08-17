require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class RevenueCode < StandardVocabularyOperator
      register __FILE__

      desc 'Searches the procedure_occurrence table for all procedures that have an associated procedure_cost record with matching revenue codes'
      argument :revenue_codes, type: :codelist, vocab: 'Revenue Code'
      predominant_domains :procedure_occurrence

      def query(db)
        if gdm?
          vocab_op.query(db)
        else
          costs = CostOp.new(nodifier, "revenue", *arguments).evaluate(db).select(:criterion_id)
          db[:procedure_occurrence].where(procedure_occurrence_id: costs)
        end
      end

      def table
        if gdm?
          vocab_op.table
        else
          :procedure_occurrence
        end
      end

      def vocabulary_id
        43
      end

      class CostOp < StandardVocabularyOperator
        include ConceptQL::Behaviors::Unwindowable

        def table
          :procedure_cost
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
end



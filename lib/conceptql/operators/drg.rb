require_relative 'standard_vocabulary_operator'

module ConceptQL
  module Operators
    class Drg < StandardVocabularyOperator
      register __FILE__

      preferred_name "DRG"
      argument :drgs, type: :codelist, vocab: 'DRG'
      predominant_domains :procedure_occurrence

      codes_should_match(/^\d{3}$/)

      def query(db)
        if gdm?
          vocab_op.query(db)
        else
          costs = CostOp.new(nodifier, "drg", *arguments).evaluate(db).select(:criterion_id)
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
        40
      end

      class CostOp < StandardVocabularyOperator
        include ConceptQL::Behaviors::Unwindowable

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
end



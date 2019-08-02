require_relative "../../operators/vocabulary"

module ConceptQL
  module Vocabularies
    module Behaviors
      module Costish
        def query(db)
          costs = CostOp.new(nodifier, "drg", *arguments).evaluate(db).select(:criterion_id)
          db[:procedure_occurrence].where(procedure_occurrence_id: costs)
        end

        def table
          :procedure_occurrence
        end

        class CostOp < ConceptQL::Operators::Vocabulary 
          include Omopish
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
end


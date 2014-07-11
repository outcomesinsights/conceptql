require_relative 'casting_node'

module ConceptQL
  module Nodes
    class VisitOccurrence < CastingNode
      def my_type
        :visit_occurrence
      end

      def i_point_at
        [ :person ]
      end

      def these_point_at_me
        %i[
          condition_occurrence
          drug_cost
          drug_exposure
          observation
          procedure_cost
          procedure_occurrence
        ]
      end
    end
  end
end

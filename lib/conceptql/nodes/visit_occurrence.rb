require_relative 'casting_node'

module ConceptQL
  module Nodes
    class VisitOccurrence < CastingNode
      desc 'Returns all visits in the database, or if given a child, converts all results to the set of visit_occurrences related to those results.'
      allows_one_child
      types :visit_occurrence

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

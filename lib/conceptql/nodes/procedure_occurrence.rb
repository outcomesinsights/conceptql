require_relative 'casting_node'

module ConceptQL
  module Nodes
    class ProcedureOccurrence < CastingNode
      def my_type
        :procedure_occurrence
      end

      def i_point_at
        [ :person ]
      end

      def these_point_at_me
        %i[
          procedure_cost
        ]
      end
    end
  end
end

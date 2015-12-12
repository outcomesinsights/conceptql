require_relative 'casting_operator'

module ConceptQL
  module Operators
    class ProcedureOccurrence < CastingOperator
      register __FILE__

      desc 'Generates all procedure_occurrence records, or, if fed a stream, fetches all procedure_occurrence records for the people represented in the incoming result set.'
      types :procedure_occurrence
      allows_one_upstream

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

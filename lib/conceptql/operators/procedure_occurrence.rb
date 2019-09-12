require_relative 'casting_operator'

module ConceptQL
  module Operators
    class ProcedureOccurrence < CastingOperator
      include ConceptQL::Behaviors::Windowable

      register __FILE__

      desc 'Generates all procedure_occurrence records, or, if fed a stream, fetches all procedure_occurrence records for the people represented in the incoming result set.'
      domains :procedure_occurrence
      allows_one_upstream
      deprecated replaced_by: "Provenance"

      def my_domain
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

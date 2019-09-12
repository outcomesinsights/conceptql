require_relative 'casting_operator'

module ConceptQL
  module Operators
    class VisitOccurrence < CastingOperator
      include ConceptQL::Behaviors::Windowable

      register __FILE__

      desc 'Generates all visit_occurrence records, or, if fed a stream, fetches all visit_occurrence records for the people represented in the incoming result set.'
      allows_one_upstream
      domains :visit_occurrence
      deprecated replaced_by: "Place Of Service"

      def my_domain
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

      def source_table
        if gdm?
          :contexts
        else
          :visit_occurrence
        end
      end
    end
  end
end

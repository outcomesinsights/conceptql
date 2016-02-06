require_relative 'casting_operator'

module ConceptQL
  module Operators
    class VisitOccurrence < CastingOperator
      register __FILE__, :omopv4

      desc 'Returns all visits in the database, or if given a upstream, converts all results to the set of visit_occurrences related to those results.'
      allows_one_upstream
      validate_at_most_one_upstream
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

require_relative 'operator'

module ConceptQL
  module Operators
    class Visit < Operator
      desc 'Generates all visit_occurrence records, or, if fed a stream, fetches all visit_occurrence records for the people represented in the incoming result set.'
      types :visit_occurrence
      allows_one_upstream

      def types
        [:visit_occurrence]
      end
    end
  end
end

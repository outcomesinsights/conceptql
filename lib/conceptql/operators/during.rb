require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class During < TemporalOperator
      register __FILE__

      desc "For each person, passes along left hand records with a start_date and end_date within a right hand record's start_date and end_date."

      def where_clause
        (within_start <= l_start_date) & (l_end_date <= within_end)
      end
    end
  end
end

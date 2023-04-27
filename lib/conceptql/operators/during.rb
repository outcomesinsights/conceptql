require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class During < TemporalOperator
      register __FILE__

      desc <<-EOF
Compares all records on a person-by-person basis between the left hand records (LHR) and the right hand records (RHR).
Any record in the LHR with a start_date and end_date that occur within the start_date and end_date of a record in the RHR is passed through.
All other records are discarded, including all records in the RHR.
      EOF

      def where_clause
        (within_start <= l_start_date) & (l_end_date <= within_end)
      end
    end
  end
end

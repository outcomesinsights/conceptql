require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class OverlappedBy < TemporalOperator
      register __FILE__

      deprecated replaced_by: "any_overlap"

      desc <<-EOF
Compares all records on a person-by-person basis between the left hand records (LHR) and the right hand records (RHR).
Any record in the LHR with a start_date that occurs between the start_date and end_date of a record in the RHR is passed through.
All other records are discarded, including all records in the RHR.
L---N---L
      R-----R
        L---Y---L

      EOF
      def where_clause
        (within_start <= l_start_date) & (l_start_date <= within_end) & (within_end <= l_end_date)
      end
    end
  end
end

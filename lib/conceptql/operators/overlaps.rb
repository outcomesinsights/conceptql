require_relative 'temporal_operator'

module ConceptQL
  module Operators
    class Overlaps < TemporalOperator
      register __FILE__

      deprecated replaced_by: "any_overlap"

      desc <<-EOF
Compares all records on a person-by-person basis between the left hand records (LHR) and the right hand records (RHR).
Any record in the LHR with an end_date that occurs between the start_date and end_date of a record in the RHR is passed through.
All other records are discarded, including all records in the RHR.
L---Y---L
      R-----R
        L---N---L
      EOF
      def where_clause
        (l_start_date <= within_start) & (within_start <= l_end_date) & (l_end_date <= within_end)
      end
    end
  end
end

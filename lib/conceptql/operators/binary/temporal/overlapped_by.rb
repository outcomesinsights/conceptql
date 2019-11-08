require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        class OverlappedBy < Base
          register __FILE__

          deprecated replaced_by: "any_overlap"

          desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date that occurs between the start_date and end_date of a result in the RHR is passed through.
All other results are discarded, including all results in the RHR.
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
  end
end

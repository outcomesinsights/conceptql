require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        class Overlaps < Base
          register __FILE__

          deprecated replaced_by: "any_overlap"

          desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with an end_date that occurs between the start_date and end_date of a result in the RHR is passed through.
All other results are discarded, including all results in the RHR.
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
  end
end

require_relative "trim_date"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        # Trims the end_date of the LHS set of results by the RHS's earliest
        # start_date (per person)
        # If a the RHS contains a start_date that comes before the LHS's start_date
        # that LHS result is completely discarded.
        #
        # If there is no RHS result for an LHS result, the LHS result is passed
        # thru unaffected.
        #
        # If the RHS result's start_date is later than the LHS end_date, the LHS
        # result is passed thru unaffected.
        class TrimDateEnd < TrimDate
          register __FILE__

          desc <<-EOF
Trims the end_date of the left hand results (LHR) by the earliest
start_date (per person) in the right hand results (RHR)
If the RHR contains a start_date that comes before the start_date in the LHR
that result in the LHR is completely discarded.

If there is no result in the RHR for a result in the LHR, the result in the LHR is passed
through unaffected.

If the start_date of the result in the RHR is later than the end_date of the result in the LHR, the result in the LHR
is passed through unaffected.
          EOF

          allows_one_upstream

          def replacement_columns
            { end_date: Sequel.function(:least, l_end_date, Sequel.function(:coalesce, within_start, l_end_date)) }
          end

          private

          def trim_date
            :start_date
          end

          def where_criteria
            (l_start_date <= within_start) | { r_start_date => nil }
          end

          def occurrence_number
            1
          end
        end
      end
    end
  end
end

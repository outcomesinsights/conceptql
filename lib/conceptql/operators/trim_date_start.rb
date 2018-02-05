require_relative 'trim_date'

module ConceptQL
  module Operators
    # Trims the start_date of the LHS set of results by the RHS's latest
    # end_date (per person)
    # If a the RHS contains an end_date that comes after the LHS's end_date
    # that LHS result is completely discarded.
    #
    # If there is no RHS result for an LHS result, the LHS result is passed
    # thru unaffected.
    #
    # If the RHS result's end_date is earlier than the LHS start_date, the LHS
    # result is passed thru unaffected.
    class TrimDateStart < TrimDate
      register __FILE__

      desc <<-EOF
Trims the start_date of the left hand results (LHR) by the final
end_date (per person) in the right hand results (RHR)
If the RHR contains an end_date that comes after the end_date in the LHR
that result in the LHR is completely discarded.

If there is no result in the RHR for a result in the LHR, the result in the LHR is passed
through unaffected.

If the end_date of the result in the RHR is earlier than the start_date of the result in the LHR, the result in the LHR
is passed through unaffected.
      EOF

      allows_one_upstream

      private

      def trim_date
        :end_date
      end

      def where_criteria
        (l_end_date >= within_end) | { r_end_date => nil }
      end

      def replacement_columns
        { start_date: Sequel.function(:greatest, l_start_date, within_end) }
      end

      def occurrence_number
        -1
      end

    end
  end
end



require_relative 'trim_date'

module ConceptQL
  module Operators
    # Trims the start_date of the LHS set of records by the RHS's latest
    # end_date (per person)
    # If a the RHS contains an end_date that comes after the LHS's end_date
    # that LHS record is completely discarded.
    #
    # If there is no RHS record for an LHS record, the LHS record is passed
    # thru unaffected.
    #
    # If the RHS record's end_date is earlier than the LHS start_date, the LHS
    # record is passed thru unaffected.
    class TrimDateStart < TrimDate
      register __FILE__

      desc <<-EOF
Trims the start_date of the left hand records (LHR) by the final
end_date (per person) in the right hand records (RHR)
If the RHR contains an end_date that comes after the end_date in the LHR
that record in the LHR is completely discarded.

If there is no record in the RHR for a record in the LHR, the record in the LHR is passed
through unaffected.

If the end_date of the record in the RHR is earlier than the start_date of the record in the LHR, the record in the LHR
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
        { start_date: Sequel.function(:greatest, l_start_date, Sequel.function(:coalesce, within_end, l_start_date)) }
      end

      def occurrence_number
        -1
      end

    end
  end
end



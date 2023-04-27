require_relative 'trim_date'

module ConceptQL
  module Operators
    # Trims the end_date of the LHS set of records by the RHS's earliest
    # start_date (per person)
    # If a the RHS contains a start_date that comes before the LHS's start_date
    # that LHS record is completely discarded.
    #
    # If there is no RHS record for an LHS record, the LHS record is passed
    # thru unaffected.
    #
    # If the RHS record's start_date is later than the LHS end_date, the LHS
    # record is passed thru unaffected.
    class TrimDateEnd < TrimDate
      register __FILE__

      desc <<-EOF
Trims the end_date of the left hand records (LHR) by the earliest
start_date (per person) in the right hand records (RHR)
If the RHR contains a start_date that comes before the start_date in the LHR
that record in the LHR is completely discarded.

If there is no record in the RHR for a record in the LHR, the record in the LHR is passed
through unaffected.

If the start_date of the record in the RHR is later than the end_date of the record in the LHR, the record in the LHR
is passed through unaffected.
      EOF

      allows_one_upstream

      private

      def trim_date
        :start_date
      end

      def where_criteria
        (l_start_date <= within_start) | { r_start_date => nil }
      end

      def replacement_columns
        { end_date: Sequel.function(:least, l_end_date, Sequel.function(:coalesce, within_start, l_end_date)) }
      end

      def occurrence_number
        1
      end
    end
  end
end


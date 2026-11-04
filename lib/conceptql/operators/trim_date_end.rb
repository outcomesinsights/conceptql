# frozen_string_literal: true

require_relative "trim_date"

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

      desc "For each patient, moves the end_date of each left-hand record back to the start_date of the right-hand record with the earliest start_date. A left-hand record that starts after that start_date is removed, and the left-hand records of a patient without right-hand records pass through unchanged."
      returns "The left-hand records, each with its end_date set to the earlier of its own end_date and the start_date of the patient's right-hand record. Left-hand records that start after that start_date are not returned. The right-hand records are not returned."
      option_meaning :left, "The left-hand stream. The operator moves the end_date of these records and passes them on."
      option_meaning :right, "The right-hand stream. For each patient, the earliest start_date of these records sets the latest end_date of the left-hand records. These records are not passed on."
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d, that is subtracted from the start_date of the right-hand record before the comparison. The adjusted date is the one that moves the end_date of the left-hand record."

      example "Each patient's span from birth to age 50 or to 1970-01-01, whichever is earlier (patients born after 1970 are dropped)",
              [ "trim_date_end", { left: [ "time_window", [ "person" ], { end: "+50y" } ],
                                   right: [ "date_range", { start: "1970-01-01", end: "1970-01-01" } ] } ]

      private

      def trim_date
        :start_date
      end

      def where_criteria
        (l_start_date <= within_start) | { r_start_date => nil }
      end

      def replacement_columns
        { end_date: Sequel.function(:least, l_end_date, Sequel.function(:coalesce, trim_date_column, l_end_date)) }
      end

      # The date that trims a left row, from one right row.
      def trim_bound
        within_start
      end

      # With compare_all, the nearest trim date of the right rows that pass.
      def trim_function
        :min
      end

      def occurrence_number
        1
      end
    end
  end
end

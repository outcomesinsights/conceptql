# frozen_string_literal: true

require_relative "trim_date"

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
      effects :keep, :change

      desc "For each patient, moves the start_date of each left-hand record forward to the end_date of the right-hand record with the latest start_date. A left-hand record that ends before that end_date is removed, and the left-hand records of a patient without right-hand records pass through unchanged."
      returns "The left-hand records, each with its start_date set to the later of its own start_date and the end_date of the patient's right-hand record. Left-hand records that end before that end_date are not returned. The right-hand records are not returned."
      option_meaning :left, "The left-hand stream. The operator moves the start_date of these records and passes them on."
      option_meaning :right, "The right-hand stream. For each patient, the end_date of the record with the latest start_date sets the earliest start_date of the left-hand records. These records are not passed on."
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d, that is added to the end_date of the right-hand record before the comparison. The adjusted date is the one that moves the start_date of the left-hand record."

      example "Each patient's span from birth to age 50, trimmed to start no earlier than 1980-01-01 (patients who were 50 before 1980 are dropped)",
              [ "trim_date_start", { left: [ "time_window", [ "person" ], { end: "+50y" } ],
                                     right: [ "date_range", { start: "1980-01-01", end: "1980-01-01" } ] } ]

      private

      def trim_date
        :end_date
      end

      def where_criteria
        (l_end_date >= within_end) | { r_end_date => nil }
      end

      def replacement_columns
        { start_date: Sequel.function(:greatest, l_start_date, Sequel.function(:coalesce, trim_date_column, l_start_date)) }
      end

      # The date that trims a left row, from one right row.
      def trim_bound
        within_end
      end

      # With compare_all, the nearest trim date of the right rows that pass.
      def trim_function
        :max
      end

      def occurrence_number
        -1
      end
    end
  end
end

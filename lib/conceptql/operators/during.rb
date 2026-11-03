# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class During < TemporalOperator
      register __FILE__

      desc "For each patient, keeps the left-hand records whose date range is inside the date range of a right-hand record. The left-hand record starts on or after the start_date of the right-hand record and ends on or before its end_date."
      returns "The left-hand records that are inside the date range of at least one right-hand record of the same patient, each record once. The right-hand records are not returned."
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d. Before the comparison, the date range of each right-hand record is widened by this amount in each direction: its start_date moves back and its end_date moves forward. Use a positive amount."

      example "All MIs for the year 2010",
              [ "during", { left: [ "icd9", "412" ], right: [ "date_range", { start: "2010-01-01", end: "2010-12-31" } ] } ]

      def where_clause
        (within_start <= l_start_date) & (l_end_date <= within_end)
      end
    end
  end
end

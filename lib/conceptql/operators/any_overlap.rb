# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class AnyOverlap < TemporalOperator
      register __FILE__

      desc "For each patient, keeps the left-hand records whose date range shares at least one day with the date range of a right-hand record."
      returns "The left-hand records that overlap the date range of at least one right-hand record of the same patient, each record once. The right-hand records are not returned."
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d. Before the comparison, the date range of each right-hand record is widened by this amount in each direction: its start_date moves back and its end_date moves forward. Use a positive amount."

      example "All MIs that overlap with the month of 2010-06",
              [ "any_overlap", { left: [ "icd9", "412" ], right: [ "date_range", { start: "2010-06-01", end: "2010-06-30" } ] } ]

      def where_clause
        ((within_start <= l_start_date) & (l_start_date <= within_end)) | ((l_start_date <= within_start) & (within_start <= l_end_date))
      end
    end
  end
end

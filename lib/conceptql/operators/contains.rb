# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class Contains < TemporalOperator
      register __FILE__
      effects :keep

      desc "For each patient, keeps the left-hand results whose date range encloses the date range of a right-hand result. The left-hand result starts on or before the start_date of the right-hand result and ends on or after its end_date."
      returns "The left-hand results that enclose the date range of at least one right-hand result of the same patient, each result once. The right-hand results are not returned."
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d. Before the comparison, the date range of each left-hand result is widened by this amount in each direction: its start_date moves back and its end_date moves forward. The returned results keep their own dates. Use a positive amount."

      example "All MIs occurring on 2010-06-22",
              [ "contains", { left: [ "icd9", "412" ], right: [ "date_range", { start: "2010-06-22", end: "2010-06-22" } ] } ]

      def where_clause
        (within_start <= r_start_date) & (r_end_date <= within_end)
      end

      def within_source_table
        Sequel[:l]
      end
    end
  end
end

# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class Before < TemporalOperator
      register __FILE__

      desc "For each patient, keeps the left-hand records whose end_date is before the latest start_date of the patient's right-hand records. With the within option, each left-hand record is compared with every right-hand record of the patient instead."
      returns "The left-hand records that end before a right-hand record of the same patient starts, each record once. The right-hand records are not returned."

      allows_at_least_option
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d. The left-hand record must also end no more than this amount before the start_date of the right-hand record. With this option, each left-hand record is compared with every right-hand record of the patient, not only with the one that starts last. Use a positive amount."
      option_meaning :at_least, "A date adjustment, such as 7d or 1w. The left-hand record must end more than this amount before the start_date of the right-hand record. Use a positive amount."

      example "All MIs that occurred before a patient's last case of diabetes (250.01)",
              [ "before", { left: [ "icd9", "412" ], right: [ "icd9", "250.01" ] } ]
      example "All MIs that occurred before a patient's first case of diabetes (250.01)",
              [ "before", { left: [ "icd9", "412" ], right: [ "first", [ "icd9", "250.01" ] ] } ]
      example "Heart attacks that end no more than 1 year before death",
              [ "before", { left: [ "icd9", "410.00", "410.01", "410.10", "410.11" ], right: [ "death" ], within: "1y" } ]
      within_skip :before

      def right_stream_query(db)
        if compare_all?
          right.evaluate(db).from_self
        else
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:max,
                                                                                                     :start_date).as(:start_date))
        end
      end

      def where_clause
        before_date = r_start_date

        before_date = adjust_date(at_least_option, before_date, true) if at_least_option

        before_clause = Sequel.expr(l_end_date < before_date)

        before_clause &= l_end_date >= within_start if within_option

        before_clause
      end

      def compare_all?
        !(options.keys & [ :within ]).empty?
      end

      def rhs_function
        compare_all? ? nil : :min
      end
    end
  end
end

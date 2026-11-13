# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class After < TemporalOperator
      register __FILE__
      effects :keep

      desc "For each patient, keeps the left-hand records whose start_date is after the earliest end_date of the patient's right-hand records. With the within option, each left-hand record is compared with every right-hand record of the patient instead."
      returns "The left-hand records that start after a right-hand record of the same patient ends, each record once. The right-hand records are not returned."

      allows_at_least_option
      option_meaning :within, "A date adjustment, such as 30d, 2m or 1y-3d. The left-hand record must also start no more than this amount after the end_date of the right-hand record. With this option, each left-hand record is compared with every right-hand record of the patient, not only with the one that ends first. Use a positive amount."
      option_meaning :at_least, "A date adjustment, such as 7d or 1w. The left-hand record must start more than this amount after the end_date of the right-hand record. Use a positive amount."

      example "All MIs that occurred after a patient's first case of diabetes (250.01)",
              [ "after", { left: [ "icd9", "412" ], right: [ "icd9", "250.01" ] } ]
      example "Prescriptions of interest within three days after an office visit",
              [ "after", { left: [ "ndc", "61392070054", "65084025214", "65726040125", { label: "Prescriptions of Interest" } ],
                           right: [ "cpt", "99214", { label: "Office Visit" } ], within: "3d" } ]
      example "Heart attack diagnoses more than 1 week after a diagnosis of diabetes",
              [ "after", { left: [ "icd9", "410.00", "410.01", "410.10", "410.11", { label: "Heart Attack Dx" } ],
                           right: [ "icd9", "250.01", { label: "Diabetes Dx" } ], at_least: "1w" } ]
      example "All MIs that occurred after a male patient's 50th birthday",
              [ "after", { left: [ "icd9", "412" ], right: [ "time_window", [ "gender", "Male" ], { start: "50y", end: "50y" } ] } ]
      within_skip :after

      def right_stream_query(db)
        if compare_all?
          right.evaluate(db).from_self
        else
          right.evaluate(db).from_self.select_group(*matching_columns).select_append(Sequel.function(:min,
                                                                                                     :end_date).as(:end_date))
        end
      end

      def where_clause
        after_date = r_end_date

        after_date = adjust_date(at_least_option, after_date) if at_least_option

        clause = Sequel.expr(l_start_date > after_date)

        clause &= l_start_date <= within_end if within_option

        clause
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

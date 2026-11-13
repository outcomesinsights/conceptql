# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Hospitalization < Operator
      register __FILE__
      effects :select
      include ConceptQL::Behaviors::Utilizable

      desc "Selects inpatient hospital admissions: one result for each admission whose claim came from an inpatient file."
      returns "One result for each inpatient admission. The type of the results is condition_occurrence, " \
              "and their criterion_table is collections, the table of claims. Their start_date and end_date " \
              "are the dates of the claim, and source_value holds the primary code of the admission when it has one. " \
              "Each result also has admission and discharge columns, such as admission_date, discharge_date and length_of_stay."
      example "All inpatient hospital admissions", [ "hospitalization" ]

      def collection_type
        "inpatient"
      end
    end
  end
end

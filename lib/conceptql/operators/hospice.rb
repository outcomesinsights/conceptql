# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Hospice < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects hospice admissions: one record for each admission whose claim came from a hospice file."
      returns "One record for each hospice admission. The type of the records is condition_occurrence, " \
              "and their criterion_table is collections, the table of claims. Their start_date and end_date " \
              "are the dates of the claim, and source_value holds the primary code of the admission when it has one. " \
              "Each record also has admission and discharge columns, such as admission_date, discharge_date and length_of_stay."
      # The test data has no hospice claims
      example "All hospice admissions", [ "hospice" ], help: false

      def collection_type
        "hospice"
      end
    end
  end
end

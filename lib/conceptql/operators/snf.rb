# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Snf < Operator
      register __FILE__
      include ConceptQL::Behaviors::Utilizable

      desc "Selects admissions to skilled nursing facilities (SNF): one record for each admission whose claim came from an SNF file."
      returns "One record for each SNF admission. The type of the records is condition_occurrence, " \
              "and their criterion_table is collections, the table of claims. Their start_date and end_date " \
              "are the dates of the claim, and source_value holds the primary code of the admission when it has one. " \
              "Each record also has admission and discharge columns, such as admission_date, discharge_date and length_of_stay."
      # The test data has no SNF claims
      example "All SNF admissions", [ "snf" ], help: false

      def collection_type
        "snf"
      end
    end
  end
end

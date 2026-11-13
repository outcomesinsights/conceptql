# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    class Equal < TemporalOperator
      register __FILE__
      effects :keep

      desc "For each patient, keeps the left-hand results whose value_as_number equals the value_as_number of a right-hand result. It does not compare dates."
      returns "The left-hand results that have a right-hand result of the same patient with the same value_as_number, each result once. Left-hand results without a value_as_number (NULL) are not returned. The right-hand results are not returned."

      # The test data has only one record with a value_as_number, so this
      # example returns no rows there and stays out of the help.
      example "HbA1c results (LOINC 4548-4) with the same value as an HbA1c result by HPLC (LOINC 17856-6) of the same patient",
              [ "equal", { left: [ "loinc", "4548-4" ], right: [ "loinc", "17856-6" ] } ], help: false

      require_column :value_as_number

      # Equal compares only value_as_number, so the within option that it
      # inherits from TemporalOperator would have no effect (seed conceptql-ufn)
      unsupported_options :within

      def where_clause
        { Sequel[:r][:value_as_number] => Sequel[:l][:value_as_number] }
      end
    end
  end
end

# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    # Filters the incoming stream of records to only those that have a
    # value_as_number column with a value that matches the specified criteria
    # are passed through
    #
    # If an record has NULL for value_as_number, it is filtered out.
    class NumericFilter < Operator
      register __FILE__
      effects :keep

      desc "Passes along the records whose value_as_number is in the given range. " \
           "Lab records, such as those of loinc, carry this value."

      returns "The upstream records whose value_as_number is in the range. " \
              "A record that has no value_as_number is not passed along."

      option :greater_than_or_equal_to, type: :float,
                                        meaning: "The lowest value_as_number that passes. Without this option, the range has no lower limit."
      option :less_than_or_equal_to, type: :float,
                                     meaning: "The highest value_as_number that passes. Without this option, the range has no upper limit."

      example "Hemoglobin A1c results (LOINC 4548-4) with a value from 5 to 7",
              [ "numeric_filter", [ "loinc", "4548-4" ], { "greater_than_or_equal_to" => 5, "less_than_or_equal_to" => 7 } ]

      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      require_column :value_as_number
      default_query_columns

      VALUE_COLUMN = Sequel[:value_as_number]

      def query(db)
        db.from(stream.evaluate(db))
          .where(range_criteria)
      end

      private

      def range_criteria
        criteria = []
        criteria << Sequel.~(VALUE_COLUMN => nil)
        criteria << gte_criteria if gte.present?
        criteria << lte_criteria if lte.present?
        criteria.inject(&:&)
      end

      def gte
        options[:greater_than_or_equal_to]
      end

      def lte
        options[:less_than_or_equal_to]
      end

      def gte_literal
        Sequel.cast_numeric(gte.to_f, Float)
      end

      def lte_literal
        Sequel.cast_numeric(lte.to_f, Float)
      end

      def gte_criteria
        gte_literal <= VALUE_COLUMN
      end

      def lte_criteria
        lte_literal >= VALUE_COLUMN
      end
    end
  end
end

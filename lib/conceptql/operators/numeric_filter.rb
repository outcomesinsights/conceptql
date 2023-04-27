require_relative "operator"
require "active_support/core_ext/object/blank"

module ConceptQL
  module Operators
    # Filters the incoming stream of records to only those that have a
    # value_as_number column with a value that matches the specified criteria
    # are passed through
    #
    # If an record has NULL for value_as_number, it is filtered out.
    class NumericFilter < Operator
      register __FILE__

      desc 'Includes records with a value_as_number that matches the given criteria.  Excludes records where value_as_number is NULL.'

      option :greater_than_or_equal_to, type: :float
      option :less_than_or_equal_to, type: :float
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
        VALUE_COLUMN <= lte_literal
      end
    end
  end
end

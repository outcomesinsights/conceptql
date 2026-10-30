# frozen_string_literal: true

require_relative "generic"

module ConceptQL
  module Rdbms
    class Spark < Generic
      def days_between(from_column, to_column)
        Sequel.function(:datediff, cast_date(to_column), cast_date(from_column))
      end

      # <=> is Spark's NULL-safe equality operator (see Generic#null_safe_equal).
      def null_safe_equal(lhs, rhs)
        Sequel.lit("(? <=> ?)", lhs, rhs)
      end

      # Spark accepts an IN subquery only in a filter or a join: "IN/EXISTS
      # predicate sub-queries can only be used in Filter/Join" (Spark 3.3).
      def supports_in_subquery_in_select?
        false
      end
    end
  end
end

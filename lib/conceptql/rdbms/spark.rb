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

      def preferred_formatter
        SqlFormatters::PG_FORMAT
      end
    end
  end
end

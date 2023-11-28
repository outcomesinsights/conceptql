require_relative "generic"

module ConceptQL
  module Rdbms
    class Spark < Generic
      def days_between(from_column, to_column)
        Sequel.function(:datediff, cast_date(to_column), cast_date(from_column))
      end

      def preferred_formatter
        SqlFormatters::PgFormat
      end
    end
  end
end

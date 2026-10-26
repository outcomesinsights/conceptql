# frozen_string_literal: true

require_relative "generic"

module ConceptQL
  module Rdbms
    class DuckDB < Generic
      def datediff(from, to)
        Sequel.function(:datediff, "day", to, from)
      end

      def preferred_formatter
        SqlFormatters::PG_FORMAT
      end

      # DuckDB accepts WITH ... AS MATERIALIZED since v0.8.0.
      def supports_materialized?
        true
      end
    end
  end
end

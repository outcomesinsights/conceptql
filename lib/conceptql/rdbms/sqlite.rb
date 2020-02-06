require_relative "generic"

module ConceptQL
  module Rdbms
    class Sqlite < Generic
      def least_function
        :min
      end

      def greatest_function
        :max
      end

      def days_between(from_column, to_column)
        expr = Sequel.function(:julianday, to_column) - Sequel.function(:julianday, from_column)
        Sequel.cast(expr, Integer)
      end

      def create_options(scope, ds)
        opts = {}
        opts[:analyze] = opts[:explain] = explain_temp_tables?
        opts
      end

      def drop_options
        {}
      end

      def post_create(db, table_name)
        db.vacuum_table(table_name, analyze: true) if analyze_temp_tables?
      end

      def preferred_formatter
        SqlFormatters::PgFormat
      end

      def analyze_temp_tables?
        ENV["CONCEPTQL_PG_ANALYZE_TEMP_TABLES"] == "true"
      end

      def explain_temp_tables?
        ENV["CONCEPTQL_PG_EXPLAIN_TEMP_TABLES"] == "true"
      end
    end
  end
end



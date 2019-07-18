require_relative "generic"

module ConceptQL
  module Rdbms
    class Postgres < Generic
      def days_between(from_column, to_column)
        cast_date(to_column) - cast_date(from_column)
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

      def preferred_formatter
        SqlFormatters::PgFormat
      end
    end
  end
end


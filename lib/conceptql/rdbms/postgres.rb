# frozen_string_literal: true

require_relative 'generic'

module ConceptQL
  module Rdbms
    class Postgres < Generic
      def days_between(from_column, to_column)
        cast_date(to_column) - cast_date(from_column)
      end

      def datediff(from, to)
        Sequel.extract(:days, Sequel.cast(from, Time) - Sequel.cast(to, Time))
      end

      def create_options(_scope, _ds)
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
        SqlFormatters::PostgresFormatter
      end

      def primary_concepts(db, all_primary_ids)
        db[Sequel[:clinical_codes].as(:pcc)]
          .where(provenance_concept_id: all_primary_ids)
          .select(
            Sequel[:pcc][:collection_id].as(:collection_id),
            Sequel[:pcc][:clinical_code_source_value].as(:concept_code),
            Sequel[:pcc][:clinical_code_vocabulary_id].as(:vocabulary_id),
            Sequel[true].as(:is_primary)
          )
          .order(Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id])
          .from_self
          .distinct(:collection_id) # This generates DISTINCT ON which is PostgreSQL-specific
      end

      def analyze_temp_tables?
        ENV['CONCEPTQL_PG_ANALYZE_TEMP_TABLES'] == 'true'
      end

      def explain_temp_tables?
        ENV['CONCEPTQL_PG_EXPLAIN_TEMP_TABLES'] == 'true'
      end

      def supports_materialized?
        true
      end
    end
  end
end

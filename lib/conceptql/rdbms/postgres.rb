# frozen_string_literal: true

require_relative "generic"

module ConceptQL
  module Rdbms
    class Postgres < Generic
      # Returns from - to (see Generic#datediff).
      def datediff(from, to)
        Sequel.extract(:days, Sequel.cast(from, Time) - Sequel.cast(to, Time))
      end

      def post_create(db, table_name)
        db.vacuum_table(table_name, analyze: true) if analyze_temp_tables?
      end

      def preferred_formatter
        SqlFormatters::POSTGRES
      end

      # DISTINCT ON is Postgres-only. The other adapters inherit
      # Generic#primary_concepts, which uses ROW_NUMBER() instead.
      def primary_concepts(db, all_primary_ids)
        db[Sequel[:clinical_codes].as(:pcc)]
          .where(provenance_concept_id: all_primary_ids)
          .select(
            Sequel[:pcc][:collection_id].as(:collection_id),
            Sequel[:pcc][:clinical_code_concept_id].as(:concept_id),
            Sequel[:pcc][:clinical_code_source_value].as(:concept_code),
            Sequel[:pcc][:clinical_code_vocabulary_id].as(:vocabulary_id),
            Sequel[true].as(:is_primary)
          )
          .order(Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id])
          .from_self
          .distinct(:collection_id)
      end

      def analyze_temp_tables?
        ENV["CONCEPTQL_PG_ANALYZE_TEMP_TABLES"] == "true"
      end

      def explain_temp_tables?
        ENV["CONCEPTQL_PG_EXPLAIN_TEMP_TABLES"] == "true"
      end

      def supports_materialized?
        true
      end
    end
  end
end

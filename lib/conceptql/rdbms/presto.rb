# frozen_string_literal: true

require_relative 'generic'

module ConceptQL
  module Rdbms
    class Presto < Generic
      def days_between(from_column, to_column)
        datediff(from_column, to_column)
      end

      def datediff(from, to)
        Sequel.function(:date_diff, 'day', from, to)
      end

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
          .distinct(:collection_id) # This generates DISTINCT ON which is PostgreSQL-specific
      end

      def preferred_formatter
        SqlFormatters::PostgresFormatter
      end

      def supports_materialized?
        false
      end
    end
  end
end

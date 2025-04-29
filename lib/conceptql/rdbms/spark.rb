# frozen_string_literal: true

require_relative 'generic'

module ConceptQL
  module Rdbms
    class Spark < Generic
      def days_between(from_column, to_column)
        Sequel.function(:datediff, cast_date(to_column), cast_date(from_column))
      end

      def preferred_formatter
        SqlFormatters::PgFormat
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
          .select_append(Sequel[:ROW_NUMBER].function.over(
            partition: :collection_id,
            order: [Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id]]
          ).as(:nummy))
          .from_self
          .where(nummy: 1)
      end
    end
  end
end

# frozen_string_literal: true

module ConceptQL
  module Rdbms
    class Generic
      def process(column, value = nil)
        type = Scope::COLUMN_TYPES.fetch(column)
        new_column = case type
        when String, :String
                       Sequel.cast_string(value)
        when Date, :Date
                       cast_date(value)
        when Float, :Bigint, :Float
                       Sequel.cast_numeric(value, type)
        else
                       raise "Unexpected type: '#{type.inspect}' for column: '#{column}'"
        end
        new_column.as(column)
      end

      def semi_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        ds.from_self(alias: :l).where(ds.db[table.as(:r)]
          .select(1)
          .where(expr)
          .exists).from_self
      end

      def cast_date(date)
        Sequel.cast(date, Date)
      end

      def days_between(from_column, to_column)
        cast_date(to_column) - cast_date(from_column)
      end

      # Impala is teh dumb in that it won't allow columns with constants to
      # be part of the partition of a window function.
      #
      # Meanwhile, the rest of the civilized RDBMS world is fine with it
      #
      # So, by default, return the name of the column and in the Impala adapter
      # we'll return something funky to trick Impala into allowing a constant
      def partition_fix(column, _qualifier = nil)
        column
      end

      def uuid
        uuid_items
          .zip([ Sequel.cast_string("/") ] * (uuid_items.length - 1))
          .flatten
          .compact
          .inject(:+)
      end

      def uuid_items
        %w[person_id criterion_id criterion_table start_date end_date].map do |column|
          Sequel.cast_string(column.to_sym)
        end
      end

      def preferred_formatter
        SqlFormatters::SQL_FORMATTER
      end

      def datediff(from, to)
        Sequel.function(:datediff, from, to)
      end

      def analyze_temp_tables?
        false
      end

      def explain_temp_tables?
        false
      end

      def supports_materialized?
        false
      end

      def create_options(_scope, _ds)
        opts = {}
        opts[:analyze] = opts[:explain] = explain_temp_tables?
        opts
      end

      def drop_options
        {}
      end

      def post_create(db, table_name); end

      # One primary clinical code per collection: the row with the lowest
      # concept id. ROW_NUMBER() works on every supported RDBMS. Postgres
      # overrides this with DISTINCT ON.
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
          .select_append(Sequel[:ROW_NUMBER].function.over(
            partition: :collection_id,
            order: [ Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id] ]
          ).as(:nummy))
          .from_self
          .where(nummy: 1)
      end
    end
  end
end

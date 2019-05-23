require_relative "generic"

module ConceptQL
  module Rdbms
    class Impala < Generic
      SORT_BY_COLUMNS = %i(person_id window_id start_date end_date)
      POSSIBLY_STATIC_COLUMNS = %i(criterion_table criterion_domain value_as_number)

      def cast_date(date)
        Sequel.cast(date, DateTime)
      end

      def semi_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        ds.from_self(alias: :l)
          .left_semi_join(table, expr, table_alias: :r)
          .select_all(:l)
      end

      # Impala is teh dumb in that it won't allow columns with constants to
      # be part of the partition of a window function.
      #
      # Concatting other constants didn't seem to fix the problem
      #
      # Since we're partitioning by person_id at all times, it seems like a
      # safe bet that we can append the person_id to any constant, making it
      # no longer a constant, but still a viable column for partitioning
      def partition_fix(column, qualifier=nil)
        return column if ENV["CONCEPTQL_DISABLE_ORDER_BY_FIX"] == "true"
        person_id = qualifier ? Sequel.qualify(qualifier, :person_id).cast_string : :person_id
        person_id = Sequel.cast_string(person_id)
        column = Sequel.expr(column).cast_string
        column + '_' + person_id
      end

      def uuid_items
        items = %w(person_id criterion_id criterion_table).map do |column|
          Sequel.cast_string(column.to_sym)
        end
        items << Sequel.function(:split_part, Sequel.cast_string(:start_date), " ", 1)
      end

      def days_between(from_column, to_column)
        Sequel.function(:datediff, cast_date(to_column), cast_date(from_column))
      end

      def create_options(scope, ds)
        opts = { parquet: true }
        if ENV["CONCEPTQL_SORT_TEMP_TABLES"] == "true"
          sort_by_columns = if ds.opts[:values]
            ds.opts[:values].first.map(&:alias)
          else
            SORT_BY_COLUMNS & scope.query_columns
          end
          opts[:sort_by] = sort_by_columns
        end
        opts
      end

      def post_create(db, table_name)
        db.compute_stats(table_name)
      end

      def drop_options
        {
          cascade: true,
          purge: true
        }
      end
    end
  end
end


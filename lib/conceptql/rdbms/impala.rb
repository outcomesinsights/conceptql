require_relative "generic"

module ConceptQL
  module Rdbms
    class Impala < Generic
      def cast_date(date)
        Sequel.cast(date, DateTime)
      end

      def semi_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        ds.from_self(alias: :l)
          .left_join(table, expr, semi: true, table_alias: :r)
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
        person_id = qualifier ? Sequel.qualify(qualifier, :person_id) : :person_id
        Sequel.expr(column).cast_string + '_' + Sequel.cast_string(person_id)
      end

      def uuid_items
        items = %w(person_id criterion_id criterion_table).map do |column|
          Sequel.cast_string(column.to_sym)
        end
        items << Sequel.function(:split_part, Sequel.cast_string(:start_date), " ", 1)
      end

      def create_options
        {
          parquet: true
        }
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


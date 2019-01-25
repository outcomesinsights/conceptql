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
          .left_semi_join(table, expr, { table_alias: :r }.merge(join_options))
          .select_all(:l)
      end

      CONCEPTQL_SEMI_JOIN_FIRST = case ENV["CONCEPTQL_SEMI_JOIN_FIRST"]
      when "true"
        true
      when "table"
        :table
      when nil, ""
        nil
      else
        raise "invalid CONCEPTQL_SEMI_JOIN_FIRST environment variable, should be true or table if set"
      end

      def inner_join(ds, table, expr, opts={}, &block)
        if CONCEPTQL_SEMI_JOIN_FIRST
          alias_name = ds.send(:alias_symbol, ds.opts[:from].first)
          ds = ds.left_semi_join(table, expr, opts, &block)

          ds = case CONCEPTQL_SEMI_JOIN_FIRST
          when :table
            temp_table = scope.cte_name("semi_join_table")
            temp_table = temp_table.column if temp_table.is_a?(Sequel::SQL::QualifiedIdentifier)
            temp_table = Sequel.identifier(temp_table) if temp_table.is_a?(String)
            ds.db.from(Sequel.as(temp_table, alias_name)).with(temp_table, ds)
          when true
            ds.from_self(:alias=>alias_name)
          end
        end

        ds.join(table, expr, join_options.merge(opts), &block)
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
        opts = { parquet: true }
        opts = opts.merge(sort_by: SORT_BY_COLUMNS & scope.query_columns) if ENV["CONCEPTQL_SORT_TEMP_TABLES"] == "true"
        opts
      end

      def post_create(db, table_name)
        db.compute_stats(table_name)
      end

      def join_options
        opts = {}
        opts = opts.merge(hints: :shuffle) if ENV["CONCEPTQL_FORCE_SHUFFLE_JOINS"] == "true"
        opts
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


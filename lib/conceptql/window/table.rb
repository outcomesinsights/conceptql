module ConceptQL
  module Window
    class Table
      attr :table_window, :cdb, :adjust_start, :adjust_end

      def initialize(table_window, cdb, adjust_start, adjust_end)
        @cdb = cdb
        @table_window = table_window
        @adjust_start = adjust_start
        @adjust_end = adjust_end
      end

      def call(op, query, opts = {})
        start_date = apply_adjustments(op, Sequel[:r][:start_date], adjust_start)
        end_date = apply_adjustments(op, Sequel[:r][:end_date], adjust_end)

        exprs = []
        exprs << Sequel.expr({ Sequel[:l][:person_id] => Sequel[:r][:person_id] })

        query = Sequel[query] if query.is_a?(Symbol)
        table = get_table_window(table_window, query)
        table = Sequel[table] if table.is_a?(Symbol)

        if op.same_table?(table)
          return query
            .select_remove(:window_id)
            .select_append{row_number.function.over(order: query.columns).as(:window_id)}
            .from_self
        end

        unless opts[:timeless]
          exprs << (start_date <= Sequel[:l][:start_date])
          exprs << (Sequel[:l][:end_date] <= end_date)
        end
        expr = exprs.inject(&:&)

        rhs = query.db[table]
        query
          .select_remove(:window_id)
          .from_self(alias: :l)
          .join(
            rhs
              .select_remove(:window_id)
              .select_append{row_number.function.over(order: order_columns(rhs.columns)).as(:window_id)}.as(:r),
            expr)
        .select_all(:l)
        .select_append(Sequel[:r][:window_id])
        .from_self
      end

      def order_columns(rhs_columns)
        return rhs_columns unless ENV["CONCEPTQL_SORT_TEMP_TABLES"] == "true"

        # It's possible we've already sorted the tables a bit, so let's try
        # to use that existing order and then order by everything else after
        already_ordered_columns = rhs_columns & ConceptQL::Rdbms::Impala::SORT_BY_COLUMNS
        already_ordered_columns + (rhs_columns - already_ordered_columns)
      end

      def get_table_window(table_window, query)
        case table_window
        when Array
          cdb.query(table_window).query
        when String
          tables = table_window.split(".")
          if tables.length == 2
            Sequel.qualify(*tables)
          else
            Sequel.identifier(table_window)
          end
        else
          table_window
        end
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment
        DateAdjuster.new(op, adjustment).adjust(column)
      end
    end
  end
end


require_relative "base"

module ConceptQL
  module Window
    # Provides a scope window based on the ConceptQL result set of another table
    class Table < Base
      def call(op, query, options = {})
        l_table = Sequel[:l]
        r_table = Sequel[:r]
        r_start_date = apply_adjustments(op, r_table[:start_date], adjust_start)
        r_end_date = apply_adjustments(op, r_table[:end_date], adjust_end)

        exprs = []
        exprs << Sequel.expr(l_table[:person_id] => r_table[:person_id])

        query = Sequel[query] if query.is_a?(Symbol)

        unless options[:timeless]
          exprs << (r_start_date <= l_table[event_start_date_column])
          exprs << (l_table[event_end_date_column] <= r_end_date)
        end
        expr = exprs.inject(&:&)

        rhs = query.db[get_table_window(query)]
        rhs = rhs
              .select_group(:person_id, :start_date, :end_date)
              .select_append do
                row_number.function.over(order: %i[person_id start_date end_date])
                          .as(:window_id)
              end.as(:r)

        op.columns.qualify_columns(:l)
        op.columns.add_columns(window_id: r_table[:window_id])
        query
          .from_self(alias: :l)
          .join(rhs, expr)
      end

      def get_table_window(query)
        case table_window
        when Array
          cdb.query(table_window).query
        when String
          tables = table_window.split(".")
          tables.length == 2 ? Sequel.qualify(*tables) : Sequel.identifier(table_window)
        when Symbol
          Sequel[table_window]
        else
          table_window
        end
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment
        DateAdjuster.new(op, adjustment).adjust(column)
      end

      def table_window
        opts[:window_table]
      end

      def cdb
        opts[:cdb]
      end

      def adjust_start
        opts[:adjust_window_start]
      end

      def adjust_end
        opts[:adjust_window_end]
      end
    end
  end
end

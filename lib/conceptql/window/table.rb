module ConceptQL
  module Window
    class Table
      attr :table_window, :adjust_start, :adjust_end

      def initialize(table_window, adjust_start, adjust_end)
        @table_window = table_window
        @adjust_start = adjust_start
        @adjust_end = adjust_end
      end

      def call(op, query)
        start_date = apply_adjustments(op, Sequel[:r][:start_date], adjust_start)
        end_date = apply_adjustments(op, Sequel[:r][:end_date], adjust_end)

        exprs = []
        exprs << (start_date <= Sequel[:l][:start_date])
        exprs << (Sequel[:l][:end_date] <= end_date)
        exprs << { Sequel[:l][:person_id] => Sequel[:r][:person_id] }

        op.rdbms.semi_join(query, table_window, *exprs)
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment
        DateAdjuster.new(op, adjustment).adjust(column)
      end
    end
  end
end


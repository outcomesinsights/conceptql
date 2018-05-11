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
        start_date = apply_adjustments(op, Sequel[:tw][:start_date], adjust_start)
        end_date = apply_adjustments(op, Sequel[:tw][:end_date], adjust_end)

        sub_select = query.db[table_window].from_self(alias: :tw)
          .where(Sequel[:og][:person_id] => Sequel[:tw][:person_id])
          .where(start_date <= Sequel[:og][:start_date])
          .where(Sequel[:og][:end_date] <= end_date)
          .select(1)

        query.from_self(alias: :og)
          .where(sub_select.exist)
          .select_all(:og)
          .from_self
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment
        DateAdjuster.new(op, adjustment).adjust(column)
      end
    end
  end
end


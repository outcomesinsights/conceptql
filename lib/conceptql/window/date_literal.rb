module ConceptQL
  module Window
    class DateLiteral
      attr :window_start, :window_end

      def initialize(start_date, end_date)
        @window_start = start_date
        @window_end = end_date
      end

      def windowfy(op, query)
        start_check = op.rdbms.cast_date(window_start) <= :start_date
        end_check = Sequel.expr(:end_date) <= op.rdbms.cast_date(window_end)
        query.from_self.where(start_check).where(end_check)
      end
    end
  end
end

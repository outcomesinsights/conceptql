require_relative "base"

module ConceptQL
  module Window
    # Provides a scope window that uses a date range literal
    class DateRange < Base
      def call(operator, ds, options = {})
        return ds if options[:timeless]

        rdbms = operator.rdbms
        ds.where(start_check(rdbms)).where(end_check(rdbms)).from_self
      end

      def start_check(rdbms)
        rdbms.cast_date(opts[:start_date]) <= event_start_date_column
      end

      def end_check(rdbms)
        event_end_date_column <= rdbms.cast_date(opts[:end_date])
      end
    end
  end
end

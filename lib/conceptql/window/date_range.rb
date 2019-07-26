module ConceptQL
  module Window
    # Provides a scope window that uses a date range literal
    class DateRange
      attr_reader :opts

      def initialize(opts = {})
        @opts = opts
      end

      def call(op, ds, options = {})
        return ds if options[:timeless]

        rdbms = op.rdbms
        ds.where(start_check(rdbms)).where(end_check(rdbms)).from_self
      end

      def start_check(rdbms)
        rdbms.cast_date(opts[:start_date]) <= :start_date
      end

      def end_check(rdbms)
        Sequel.expr(:end_date) <= rdbms.cast_date(opts[:end_date])
      end
    end
  end
end

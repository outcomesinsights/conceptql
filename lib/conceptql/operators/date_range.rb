require_relative 'operator'
require 'date'

module ConceptQL
  module Operators
    # Represents a operator that will create a date_range for every person in the database
    #
    # Accepts two params: start and end formateed as 'YYYY-MM-DD' or 'START' or 'END'
    # 'START' represents the first date of data in the data source,
    # 'END' represents the last date of data in the data source,
    class DateRange < Operator
      register __FILE__

      DATE_FORMAT = /\A#{Regexp.union([/START/i, /END/i, /\d{4}-\d{2}-\d{2}/])}\z/

      desc "Used to represent a date literal.  Dates must be in the format YYYY-MM-DD"
      option :start, type: :string
      option :end, type: :string
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_no_arguments
      validate_option DATE_FORMAT, :start, :end
      validate_required_options :start, :end

      def query(db)
        replace = {
          start_date:  start_date(db),
          end_date:  end_date(db)
        }
        db.from(source_table)
          .select(*dm.columns(table: source_table, replace: replace))
          .from_self
      end

      def domains(db)
        [:person]
      end

      private

      def source_table
        dm.table_by_domain(:person)
      end

      def start_date(db)
        date_from(db, options[:start])
      end

      def end_date(db)
        date_from(db, options[:end])
      end

      # TODO: Select the earliest and latest dates of observation from
      # the proper CDM table to represent the start and end of data
      def date_from(db, str)
        return db.from(period_table).get { |o| o.min(period_start_date(db)) } if str.upcase == 'START'
        return db.from(period_table).get { |o| o.max(period_end_date(db)) } if str.upcase == 'END'
        return str
      end

      def period_table
        dm.period_table
      end

      def period_start_date(db)
        dm.start_date_column(db, period_table)
      end

      def period_end_date(db)
        dm.end_date_column(db, period_table)
      end
    end
  end
end


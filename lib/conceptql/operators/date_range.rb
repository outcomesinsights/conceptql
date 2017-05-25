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

      def query_cols
        table_columns(source_table) + [:criterion_table, :criterion_domain, :criterion_id, :start_date, :end_date]
      end

      def query(db)
        db.from(source_table)
          .select_append(Sequel.cast_string(source_table.to_s).as(:criterion_table))
          .select_append(Sequel.cast_string('person').as(:criterion_domain))
          .select_append(Sequel.expr(id_column(source_table)).as(:criterion_id))
          .select_append(Sequel.as(cast_date(db, start_date(db)), :start_date),
                         Sequel.as(cast_date(db, end_date(db)), :end_date)).from_self
      end

      def domains(db)
        [:person]
      end

      private

      def source_table
        if oi_cdm?
          :patients
        else
          :person
        end
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
        if oi_cdm?
          :information_periods
        else
          :observation_period
        end
      end

      def period_start_date(db)
        start_date_column(db, period_table)
      end

      def period_end_date(db)
        end_date_column(db, period_table)
      end
    end
  end
end


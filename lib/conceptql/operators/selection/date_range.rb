require_relative "base"
require "date"

module ConceptQL
  module Operators
    module Selection
      # Represents a operator that will create a date_range for every person in the database
      #
      # Accepts two params: start and end formateed as 'YYYY-MM-DD' or 'START' or 'END'
      # 'START' represents the first date of data in the data source,
      # 'END' represents the last date of data in the data source,
      class DateRange < Base
        register __FILE__

        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Timeless

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
          super(db).auto_columns(
            start_date: start_date(db),
            end_date: end_date(db)
          )
        end

        def domains(db)
          [:person]
        end

        def where_clause(db)
          nil
        end

        private

        def table
          dm.nschema.people_cql
        end

        def start_date(db)
          rdbms.cast_date(date_from(db, options[:start]))
        end

        def end_date(db)
          rdbms.cast_date(date_from(db, options[:end]))
        end

        # TODO: Select the earliest and latest dates of observation from
        # the proper CDM table to represent the start and end of data
        def date_from(db, str)
          return db.from(period_table.name).get { |o| o.min(period_start_date(db)) } if str.upcase == 'START'
          return db.from(period_table.name).get { |o| o.max(period_end_date(db)) } if str.upcase == 'END'
          return str
        end

        def period_table
          dm.nschema.information_periods
        end

        def period_start_date(db)
          period_table.start_date.name
        end

        def period_end_date(db)
          period_table.end_date.name
        end
      end
    end
  end
end


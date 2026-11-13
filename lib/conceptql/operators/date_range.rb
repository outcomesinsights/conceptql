# frozen_string_literal: true

require_relative "operator"
require "date"

module ConceptQL
  module Operators
    # Represents a operator that will create a date_range for every person in the database
    #
    # Accepts two params: start and end formateed as 'YYYY-MM-DD' or 'START' or 'END'
    # 'START' represents the first date of data in the data source,
    # 'END' represents the last date of data in the data source,
    class DateRange < Operator
      register __FILE__
      effects :select

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      DATE_FORMAT = /\A#{Regexp.union([ /START/i, /END/i, /\d{4}-\d{2}-\d{2}/ ])}\z/.freeze

      desc "Makes one person result for each patient, with the given start_date and end_date. " \
           "Use it to compare other results with a fixed range of dates."
      option :start, type: :string,
                     meaning: "The start_date of each result. It is a date in YYYY-MM-DD format, START or END. " \
                              "START is the earliest start date of any information period in the database, " \
                              "and END is the latest end date. START and END are not case-sensitive."
      option :end, type: :string,
                   meaning: "The end_date of each result. It is a date in YYYY-MM-DD format, START or END. " \
                            "START is the earliest start date of any information period in the database, " \
                            "and END is the latest end date. START and END are not case-sensitive. " \
                            "For a single day, give the same date as the start option."
      returns "One result for each patient. The type of the results is person, " \
              "and each result has the start_date and the end_date that the options give."
      example "Each patient, with the dates of the year 2010", [ "date_range", { "start" => "2010-01-01", "end" => "2010-12-31" } ]
      example "Each patient, with the dates from the start to the end of the dataset", [ "date_range", { "start" => "START", "end" => "END" } ]
      category "Select by Property"
      diagram_base :selection
      validate_no_upstreams
      validate_no_arguments
      validate_option DATE_FORMAT, :start, :end
      validate_required_options :start, :end

      def query(db)
        replace = {
          start_date: start_date(db),
          end_date: end_date(db)
        }
        db.from(source_table)
          .select(*dm.columns(table: source_table, replace: replace))
          .from_self
      end

      def domains(_db)
        [ :person ]
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
        return db.from(period_table).get { |o| o.min(period_start_date(db)) } if str.upcase == "START"
        return db.from(period_table).get { |o| o.max(period_end_date(db)) } if str.upcase == "END"

        str
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

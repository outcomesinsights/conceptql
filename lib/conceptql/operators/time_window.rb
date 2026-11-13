# frozen_string_literal: true

require_relative "pass_thru"
require_relative "../date_adjuster"

module ConceptQL
  module Operators
    # A TimeWindow adjusts the start_date and end_date the incoming stream by the values specified in
    # the start and end arguments.
    #
    # Start and end take the format of ([+-]\d*[dwmy])+.  For example:
    # 'd' => adjust date by one day.  2012-10-07 => 2012-10-08
    # 'w' => adjust date by one week. 2012-10-07 => 2012-10-14
    # 'm' => adjust date by one month. 2012-10-07 => 2012-11-07
    # 'y' => adjust date by one year. 2012-10-07 => 2013-10-07
    # '1y' => adjust date by one year. 2012-10-07 => 2013-10-07
    # '1d1y' => adjust date by one day and one year. 2012-10-07 => 2013-10-08
    # '-1d' => adjust date by negative one day. 2012-10-07 => 2012-10-06
    # '-1d1y' => adjust date by negative one day and positive one year. 2012-10-07 => 2013-10-06
    # '', '0', nil => don't adjust date at all
    #
    # Both start and end arguments must be provided, but if you do not wish to adjust a date just
    # pass '', '0', or nil as that argument.  E.g.:
    # start: 'd', end: '' # Only adjust start_date by positive 1 day and leave end_date uneffected
    class TimeWindow < PassThru
      register __FILE__
      effects :change

      # The values that the start and end options take (DateAdjuster)
      DATE_ADJUSTMENT_TEXT = "The value is an amount of time, made of one or more numbers, each with a unit: " \
                             "d (days), w (weeks), m (months) or y (years). Each part can have a - or + sign, " \
                             "a bare number means days, and a unit without a number means 1 of it. " \
                             "For example, -1m is 1 month back, and 10d3m is 3 months and 10 days. " \
                             "An empty value or 0 leaves the date unchanged. The value start or end uses the " \
                             "record's start_date or end_date, and a date in YYYY-MM-DD format sets the date to that date."

      desc "Moves the start_date and the end_date of each record. " \
           "Use it to shift or widen a record's dates before you compare them with other records."
      option :start, type: :string,
                     instructions: 'Enter a number followed by "d", "w", "m" or "y" for days, weeks, months or years, such as 30d. A negative number moves the date earlier. You can also enter start, end or a date in YYYY-MM-DD format.',
                     meaning: "How to change the start_date. If you omit it, the start_date does not change. #{DATE_ADJUSTMENT_TEXT}"
      option :end, type: :string,
                   instructions: 'Enter a number followed by "d", "w", "m" or "y" for days, weeks, months or years, such as 30d. A negative number moves the date earlier. You can also enter start, end or a date in YYYY-MM-DD format.',
                   meaning: "How to change the end_date. If you omit it, the end_date does not change. #{DATE_ADJUSTMENT_TEXT}"
      returns "One record for each upstream record, with the start_date and the end_date that the options give. " \
              "The other columns do not change."
      example "All Diagnoses of Diabetes (ICD-9 250.01) within 30 days of an MI",
              [ "during", { "left" => [ "icd9", "250.01" ], "right" => [ "time_window", [ "icd9", "412" ], { "start" => "-30d", "end" => "30d" } ] } ]
      example "Shift the dates of all MIs back by 200 years", [ "time_window", [ "icd9", "412" ], { "start" => "-200y", "end" => "-200y" } ]
      example "Widen the dates of all MIs to run from 2 months and 2 days before the MI to 1 year and 3 days after it",
              [ "time_window", [ "icd9", "412" ], { "start" => "-2m-2d", "end" => "3d1y" } ]
      example "Collapse the date range of all MIs to the start date: leave start_date unchanged and set end_date to start_date",
              [ "time_window", [ "icd9", "412" ], { "start" => "", "end" => "start" } ]
      example "Nonsensical, but allowed: swap the start_date and end_date",
              [ "time_window", [ "icd9", "412" ], { "start" => "end", "end" => "start" } ]
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      validate_option DateAdjuster::VALID_INPUT, :start, :end
      category "Modify Data"
      basic_type :temporal

      def query(db)
        dm.selectify(db.from(stream.evaluate(db)).from_self,
                     replace: { start_date: adjusted_start_date, end_date: adjusted_end_date })
      end

      private

      def adjusted_start_date
        adjusted_date(:start, :start_date)
      end

      def adjusted_end_date
        adjusted_date(:end, :end_date)
      end

      def adjusted_date(option_arg, column)
        DateAdjuster.new(self, options[option_arg], manipulator: options[:manipulator]).adjust(column)
      end
    end
  end
end

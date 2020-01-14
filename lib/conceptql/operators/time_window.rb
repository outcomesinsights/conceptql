require_relative 'pass_thru'
require_relative '../date_adjuster'

module ConceptQL
  module Operators
    # A TimeWindow adjusts the start_date and end_date the incoming stream by the values specified in
    # the start and end arguments.
    #
    # Start and end take the format of ([+-]\d*[mdy])+.  For example:
    # 'd' => adjust date by one day.  2012-10-07 => 2012-10-08
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

      desc 'Adjusts the start_date and end_date to create a new window of time for each result.'
      option :start, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date.'
      option :end, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date.'
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments
      validate_option DateAdjuster::VALID_INPUT, :start, :end
      category "Modify Data"
      basic_type :temporal

      def query(db)
        dm.selectify(db.from(stream.evaluate(db)).from_self, replace: { start_date: adjusted_start_date, end_date: adjusted_end_date })
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


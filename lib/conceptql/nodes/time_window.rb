require_relative 'node'
require_relative '../date_adjuster'

module ConceptQL
  module Nodes
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
    class TimeWindow < Node
      def query(db)
        db.from(stream.evaluate(db))
      end

      private
      def date_columns
        [adjusted_start_date, adjusted_end_date]
      end

      def adjusted_start_date
        adjusted_date(:start, :start_date)
      end

      def adjusted_end_date
        adjusted_date(:end, :end_date)
      end

      # NOTE: This produces PostgreSQL-specific date adjustment.  I'm not yet certain how to generalize this
      # or make different versions based on RDBMS
      def adjusted_date(option_arg, column)
        arg = options[option_arg]
        arg ||= ''
        return ['end_date', column].join('___').to_sym if arg.downcase == 'end'
        return ['start_date', column].join('___').to_sym if arg.downcase == 'start'
        DateAdjuster.new(arg).adjustments.inject(Sequel.function(:date, column)) do |sql, adjustment|
          Sequel.function(:date, sql + Sequel.lit("interval '#{adjustment}'"))
        end.as(column)
      end
    end
  end
end


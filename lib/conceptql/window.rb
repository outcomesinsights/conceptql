# frozen_string_literal: true

require_relative "window/table"
require_relative "window/date_range"

module ConceptQL
  # Provides a singleton method which will return a series of scope windows
  # that should be applied to each selection operator in a ConceptQL statement
  module Window
    # The errors of the window options, as Query reports them on the window
    # operator: [message, *details]
    MISSING_DATE_ERROR = "date range needs start_date and end_date"
    SCOPE_BY_ERROR = "scope_by must be start_date, end_date or date_range"

    class << self
      EVENT_DATE_COLUMNS = {
        nil => %i[start_date start_date],
        start_date: %i[start_date start_date],
        end_date: %i[end_date end_date],
        date_range: %i[start_date end_date]
      }.freeze

      def from(opts)
        fetch_windows(prep_options(opts))
      end

      # The errors of the window options: one of start_date and end_date
      # without the other (the detail names the missing option), and a
      # scope_by that is not a known value (the detail is the value). A
      # scope_by of nil is the default, start_date.
      def option_errors(opts)
        dates = %i[start_date end_date]
        given = dates.select { |date| opts[date] }
        errors = []
        errors << [ MISSING_DATE_ERROR, (dates - given).first.to_s ] if given.one?
        scope_by = opts[:scope_by]
        errors << [ SCOPE_BY_ERROR, scope_by.to_s ] unless EVENT_DATE_COLUMNS.key?(scope_by&.to_s&.to_sym)
        errors
      end

      def fetch_windows(opts)
        windows = []

        windows << date_range_window(opts) if use_date_range?(opts)

        windows << table_window(opts) if use_table_window?(opts)

        windows << person_filter(opts) if use_person_filter?(opts)

        windows
      end

      def use_date_range?(opts)
        opts[:start_date] && opts[:end_date]
      end

      def use_table_window?(opts)
        opts[:window_table]
      end

      def use_person_filter?(opts)
        opts[:person_ids]
      end

      def date_range_window(opts)
        DateRange.new(opts)
      end

      def person_filter(opts)
        lambda do |_, ds, _options = {}|
          ds.where(person_id: opts[:person_ids])
        end
      end

      def table_window(opts)
        Table.new(opts)
      end

      def prep_options(opts)
        # Query refuses a statement with an unknown scope_by (option_errors),
        # so this raise is an assertion.
        scope_by = (opts[:scope_by] || :start_date).to_sym
        raise "#{SCOPE_BY_ERROR}: #{scope_by.inspect}" unless EVENT_DATE_COLUMNS.key?(scope_by)

        start_col, end_col = *(EVENT_DATE_COLUMNS[scope_by])
        opts.merge(
          event_start_date_column: start_col,
          event_end_date_column: end_col
        )
      end
    end
  end
end

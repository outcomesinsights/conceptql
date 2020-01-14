require_relative "window/table"
require_relative "window/date_range"

module ConceptQL
  # Provides a singleton method which will return a series of scope windows
  # that should be applied to each selection operator in a ConceptQL statement
  module Window
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

      def fetch_windows(opts)
        windows = []

        windows << person_filter(opts) if use_person_filter?(opts)

        windows << date_range_window(opts) if use_date_range?(opts)

        if use_table_window?(opts)
          windows << table_window(opts)
        end

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
          ds.where(opts.fetch(:qualifier, Sequel)[:person_id] => opts[:person_ids])
        end
      end

      def table_window(opts)
        Table.new(opts)
      end

      def prep_options(opts)
        scope_by = opts.fetch(:scope_by, :start_date).to_sym
        raise "Unknown scope_by value #{scope_by.inspect}" unless EVENT_DATE_COLUMNS.key?(scope_by)
        start_col, end_col = *(EVENT_DATE_COLUMNS[scope_by])
        opts.merge(
          event_start_date_column: start_col,
          event_end_date_column: end_col
        )
      end
    end
  end
end

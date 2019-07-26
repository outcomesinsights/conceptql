require_relative "window/table"
require_relative "window/date_range"

module ConceptQL
  # Provides a singleton method which will return a series of scope windows
  # that should be applied to each selection operator in a ConceptQL statement
  module Window
    class << self
      def from(opts)
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
    end
  end
end

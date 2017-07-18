require_relative "window/none"
require_relative "window/date_literal"
require_relative "window/table"

module ConceptQL
  module Window
    class << self
      def from(opts)
        start_date = opts[:start_date]
        end_date = opts[:end_date]
        window_table = opts[:window_table]

        if start_date && end_date
          return DateLiteral.new(start_date, end_date)
        elsif window_table
          Table.new(window_table)
        else
          None.new
        end
      end
    end
  end
end

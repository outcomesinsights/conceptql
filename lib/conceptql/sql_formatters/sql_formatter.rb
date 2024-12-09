require_relative 'formatter'

module ConceptQL
  module SqlFormatters
    class SqlFormatter < Formatter
      def program
        'sql-formatter'
      end
    end
  end
end


# frozen_string_literal: true

require_relative 'formatter'

module ConceptQL
  module SqlFormatters
    class PostgresFormatter < Formatter
      def program
        'sql-formatter'
      end

      def arguments
        %w[-l postgresql]
      end
    end
  end
end

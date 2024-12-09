# frozen_string_literal: true

require_relative 'formatter'

module ConceptQL
  module SqlFormatters
    class PrestoFormatter < Formatter
      def program
        'sql-formatter'
      end

      def arguments
        %w[-l trino]
      end
    end
  end
end

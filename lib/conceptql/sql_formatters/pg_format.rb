# frozen_string_literal: true

require_relative 'formatter'

module ConceptQL
  module SqlFormatters
    class PgFormat < Formatter
      def program
        'pg_format'
      end
    end
  end
end

require_relative "generic"

module ConceptQL
  module Rdbms
    class Spark < Generic
      def preferred_formatter
        SqlFormatters::PgFormat
      end
    end
  end
end


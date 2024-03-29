require_relative "sql_formatters/formatter"
require_relative "sql_formatters/sqlformat"
require_relative "sql_formatters/pg_format"

module ConceptQL
  module SqlFormatters
    class None
      def available?
        true
      end

      def format(sql)
        sql
      end
    end

    class << self
      def format(sql, rdbms)
        formatters(rdbms).map(&:new).detect(&:available?).format(sql)
      end

      def formatters(rdbms)
        [
          rdbms.preferred_formatter,
          Sqlformat,
          PgFormat,
          None
        ].compact
      end
    end
  end
end

require_relative 'sql_formatters/formatter'
require_relative 'sql_formatters/pg_format'
require_relative 'sql_formatters/postgres_formatter'
require_relative 'sql_formatters/sql_formatter'
require_relative 'sql_formatters/presto_formatter'
require_relative 'sql_formatters/sqlformat'

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
          SqlFormatter,
          Sqlformat,
          PgFormat,
          None
        ].compact
      end
    end
  end
end

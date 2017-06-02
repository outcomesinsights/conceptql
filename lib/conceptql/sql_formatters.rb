require_relative "sql_formatters/formatter"
require_relative "sql_formatters/sqlformat"
require_relative "sql_formatters/pg_format"

module ConceptQL
  module SqlFormatters
    class None
      def availabe?
        true
      end

      def format(sql)
        sql
      end
    end

    def self.formatters
      [
        Sqlformat,
        PgFormat,
        None
      ]
    end
  end
end

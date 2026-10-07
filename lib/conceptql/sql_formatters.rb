# frozen_string_literal: true

require_relative 'sql_formatters/formatter'

module ConceptQL
  module SqlFormatters
    SQL_FORMATTER = %w[sql-formatter].freeze
    POSTGRES = %w[sql-formatter -l postgresql].freeze
    SQLFORMAT = %w[sqlformat --reindent --use_space_around_operators --identifiers lower --keywords upper -].freeze
    PG_FORMAT = %w[pg_format].freeze

    # Formats with the rdbms's preferred formatter, else the first of the
    # fallbacks that is installed, else returns the SQL untouched.
    def self.format(sql, rdbms)
      formatter = [rdbms.preferred_formatter, SQL_FORMATTER, SQLFORMAT, PG_FORMAT]
                  .compact
                  .map { |command| Formatter.new(command) }
                  .detect(&:available?)
      formatter ? formatter.format(sql) : sql
    end
  end
end

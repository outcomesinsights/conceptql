# frozen-string-literal: true

# Allows for EXPLAIN ANALYZE to be run on a CTAS statement
module Sequel
  # Module that overrides #create_table_as and #create_table_as_sql
  module PgCtasExplain
    def create_table_as(name, sql, options)
      return super unless options[:explain]

      sql = sql.sql if sql.is_a?(Sequel::Dataset)
      explain(create_table_as_sql(name, sql, options), options)
    end

    def explain(sql, options = {})
      operations = ['EXPLAIN']
      operations << 'ANALYZE' if options[:analyze]
      log_info(fetch("#{operations.join(' ')} #{sql}").map(:'QUERY PLAN').join("\r\n"))
    end
  end

  Database.register_extension(:pg_ctas_explain, PgCtasExplain)
end

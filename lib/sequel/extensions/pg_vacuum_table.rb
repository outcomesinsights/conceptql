# frozen-string-literal: true

# Adds DB#vacuum_table method
module Sequel
  # Adds DB#vacuum_table method
  module PgVacuumTable
    def vacuum_table(table_name, opts = {})
      run(vacuum_table_sql(table_name, opts))
    end

    def vacuum_table_sql(table_name, opts)
      dataset.with_sql(vacuum_operations(opts).join(' '), table_name).sql
    end

    def vacuum_operations(opts)
      operations = ['VACUUM']
      operations << 'ANALYZE' if opts[:analyze]
      operations << '?'
    end
  end

  Database.register_extension(:pg_vacuum_table, PgVacuumTable)
end

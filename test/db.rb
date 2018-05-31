require 'sequelizer'

DB = Object.new.extend(Sequelizer).db unless defined?(DB)
if DB.database_type == :impala
  # Make sure to issue USE statement for every new connection
  ac = DB.pool.after_connect
  DB.pool.after_connect = proc do |conn, server, db|
    DB.send(:log_connection_execute, conn, "USE #{DB.opts[:database]}")
    ac.call(conn, server, db) if ac
  end

  # Remove existing connnections, so that the next query will use a new connection
  # that the USE statement has been executed on
  DB.disconnect
end

if %w(omopv4 omopv4_plus).include?(ENV['CONCEPTQL_DATA_MODEL']) && !DB.table_exists?(:source_to_concept_map)
  $stderr.puts <<END
The source_to_concept_map table doesn't exist in this database,
so it appears this doesn't include the necessary OMOP vocabulary
data. Please review the README for how to setup the test database
with the vocabulary, which needs to be done before running tests.
END
  exit 1
end


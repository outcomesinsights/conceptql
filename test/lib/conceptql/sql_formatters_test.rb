# frozen_string_literal: true

require "tmpdir"
require_relative "../../helper"
require "conceptql/rdbms"
require "conceptql/rdbms/duckdb"

# Pins which formatter command SqlFormatters.format runs for each rdbms. PATH is
# swapped for a directory holding only `which` and fake formatters that print
# their own command line, so the result does not depend on what the host has.
describe ConceptQL::SqlFormatters do
  let(:sql) { "select 1" }

  def format_with(installed, rdbms)
    which = ENV.fetch("PATH").split(":").map { |dir| File.join(dir, "which") }.find { |path| File.executable?(path) }
    Dir.mktmpdir do |dir|
      File.symlink(which, File.join(dir, "which"))
      installed.each do |name|
        path = File.join(dir, name)
        File.write(path, "#!/bin/sh\nwhile read -r line; do :; done\necho #{name} \"$@\"\n")
        File.chmod(0o755, path)
      end
      old_path = ENV.fetch("PATH")
      begin
        ENV["PATH"] = dir
        ConceptQL::SqlFormatters.format(sql, rdbms).chomp
      ensure
        ENV["PATH"] = old_path
      end
    end
  end

  all = %w[sql-formatter sqlformat pg_format]
  sqlformat = "sqlformat --reindent --use_space_around_operators --identifiers lower --keywords upper -"

  {
    ConceptQL::Rdbms::Generic => "sql-formatter",
    ConceptQL::Rdbms::Postgres => "sql-formatter -l postgresql",
    ConceptQL::Rdbms::Presto => "sql-formatter -l postgresql",
    ConceptQL::Rdbms::Spark => "pg_format",
    ConceptQL::Rdbms::DuckDB => "pg_format"
  }.each do |klass, preferred|
    describe klass.name do
      let(:rdbms) { klass.new }

      it "uses the preferred formatter when everything is installed" do
        _(format_with(all, rdbms)).must_equal preferred
      end

      it "falls back to sql-formatter, then sqlformat, then pg_format, then the raw SQL" do
        _(format_with(%w[sql-formatter sqlformat], rdbms)).must_equal(preferred == "pg_format" ? "sql-formatter" : preferred)
        _(format_with(%w[sqlformat pg_format], rdbms)).must_equal(preferred == "pg_format" ? "pg_format" : sqlformat)
        _(format_with(%w[sqlformat], rdbms)).must_equal sqlformat
        _(format_with(%w[pg_format], rdbms)).must_equal "pg_format"
        _(format_with([], rdbms)).must_equal sql
      end
    end
  end

  it "returns the raw SQL when the formatter times out" do
    ConceptQL::Utils.stub(:timed_capture, ->(*) { raise Timeout::Error }) do
      _(format_with(all, ConceptQL::Rdbms::Postgres.new)).must_equal sql
    end
  end
end

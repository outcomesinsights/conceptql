# frozen_string_literal: true

# Validates and runs every ConceptQL block of doc/spec.md.cql, and writes the
# annotated statement and the first 10 rows of each one to
# claude_stuff/spec-results.json for knit.rb. It needs the database that
# `just test-duckdb` sets up, so `just spec` runs it through that recipe.
require_relative "../../test/db_helper"
require_relative "blocks"

root = File.expand_path("../..", __dir__)
blocks = SpecBlocks.read(File.join(root, "doc/spec.md.cql"))
stored = blocks.find { |b| b.title.start_with?("All Pneumonia Diagnoses and Hospital Visits reported in the same source record") }
raise "doc/spec.md.cql has no block for stored algorithm 2031" unless stored

# The spec's algorithm example reads stored statement 2031. The fixture has no
# concepts table, so the harness supplies the statement above for that ID.
fetcher = proc { |id| id.to_i == 2031 ? [ stored.statement, "stored" ] : nil }
query = ->(statement) { CDB.query(statement, algorithm_fetcher: fetcher) }

results = blocks.map do |b|
  print format("[%02d] line %4d %-70s ", b.index, b.line, b.title[0, 70])
  errors = query.(b.statement).validation_errors
  raise "block #{b.index} (line #{b.line}) is not valid: #{errors}" unless errors.empty?

  warnings = query.(b.statement).scope_annotate(skip_counts: true)[:warnings]
  ds = DB.from(query.(b.statement).query)
  rows = ds.order(:person_id, :criterion_domain, :start_date, :criterion_id).limit(10).all
  puts "OK total=#{ds.count}#{" WARN #{warnings.inspect}" unless warnings.to_a.empty?}"
  { index: b.index, line: b.line, statement: b.statement,
    annotated: query.(b.statement).annotate,
    rows: rows.map { |row| row.transform_values { |v| v.respond_to?(:iso8601) ? v.to_s : v } } }
end
File.write(File.join(root, "claude_stuff/spec-results.json"), JSON.pretty_generate(results))
puts "#{results.size} blocks valid and run"

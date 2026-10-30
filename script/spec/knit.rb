# frozen_string_literal: true

# Writes doc/spec.md from doc/spec.md.cql and claude_stuff/spec-results.json
# (harness.rb writes it), and draws doc/spec/<sha>.png for each statement with
# graphviz `dot`. `just spec` runs both and then formats doc/spec.md.
require "json"
require "yaml"
require "open3"
require "fileutils"
require_relative "blocks"
require_relative "old_inspect"
require_relative "grapher"

root = File.expand_path("../..", __dir__)
cql = File.join(root, "doc/spec.md.cql")
img_dir = File.join(root, "doc/spec")
dot_dir = File.join(root, "claude_stuff/spec-dot")

blocks = SpecBlocks.read(cql)
results = JSON.parse(File.read(File.join(root, "claude_stuff/spec-results.json")))
raise "#{blocks.size} blocks but #{results.size} results: run harness.rb again" unless blocks.size == results.size

blocks.zip(results).each do |b, r|
  raise "block #{b.index} (line #{b.line}) differs from its result: run harness.rb again" unless b.statement == r["statement"]
end

# --- diagrams ----------------------------------------------------------------------------
FileUtils.mkdir_p([ img_dir, dot_dir ])
wanted = blocks.zip(results).to_h { |b, r| [ OldInspect.sha(b.statement), r["annotated"] ] }
wanted.each do |sha, annotated|
  dot = SpecGrapher.dot(annotated)
  File.write(File.join(dot_dir, "#{sha}.dot"), dot)
  out, status = Open3.capture2e("dot", "-Tpng", "-o", File.join(img_dir, "#{sha}.png"), stdin_data: dot)
  raise "dot failed for #{sha}: #{out}" unless status.success?
end
stale = Dir[File.join(img_dir, "*.png")].reject { |f| wanted.key?(File.basename(f, ".png")) }
FileUtils.rm(stale)
puts "diagrams: #{wanted.size} written, #{stale.size} stale removed"

# --- markdown ----------------------------------------------------------------------------
VALUE_OPS = %w[numeric sum count numeric_filter].freeze
BASE_COLS = %w[person_id criterion_id criterion_table criterion_domain start_date end_date source_value].freeze

def uses_value_ops?(stmt)
  case stmt
  when Array then VALUE_OPS.include?(stmt.first.to_s) || stmt.any? { |s| uses_value_ops?(s) }
  when Hash then stmt.values.any? { |v| uses_value_ops?(v) }
  else false
  end
end

def table(statement, rows)
  return "`No Results found.`" if rows.empty?

  cols = BASE_COLS + (uses_value_ops?(statement) ? [ "value_as_number" ] : [])
  lines = [ "| #{cols.join(' | ')} |", "| #{cols.map { |c| '-' * c.length }.join(' | ')} |" ]
  lines.concat(rows.map { |row| "| #{cols.map { |c| row[c].to_s }.join(' | ')} |" })
  lines.join("\n")
end

# Each ConceptQL block becomes a YAML block, its diagram and its result table.
pending = blocks.zip(results)
out = []
in_block = false
File.readlines(cql).each do |line|
  if in_block
    in_block = false if line.start_with?("```")
  elsif line.start_with?("```ConceptQL")
    in_block = true
    b, r = pending.shift
    out << "```YAML\n#{OldInspect.symbolize(b.statement).to_yaml}\n```\n\n"
    out << "![#{b.title.delete('[]')}](spec/#{OldInspect.sha(b.statement)}.png)\n\n"
    out << "#{table(b.statement, r['rows'])}\n"
  else
    out << line
  end
end
File.write(File.join(root, "doc/spec.md"), out.join)
puts "wrote doc/spec.md (#{blocks.size} blocks)"

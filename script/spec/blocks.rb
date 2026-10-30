# frozen_string_literal: true

require "json"

# The ```ConceptQL blocks of doc/spec.md.cql. A block holds `#` comment lines
# (its title) and one statement in JSON.
module SpecBlocks
  Block = Struct.new(:index, :line, :title, :statement, keyword_init: true)

  def self.read(path)
    lines = File.readlines(path)
    blocks = []
    lines.each_with_index do |line, i|
      next unless line.start_with?("```ConceptQL")

      body = lines[(i + 1)..].take_while { |l| !l.start_with?("```") }
      titles, statement = body.partition { |l| l.match?(/^\s*#/) }
      blocks << Block.new(index: blocks.size, line: i + 1,
                          title: titles.map { |l| l.sub(/^\s*#\s?/, "").strip }.join(" "),
                          statement: JSON.parse(statement.join))
    end
    blocks
  end
end

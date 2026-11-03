# frozen_string_literal: true

require_relative "../../helper"

# The Jigsaw diagram editor serves the spec over MCP in sections, which it
# splits by this rule: a section starts at each line that begins with "## "
# outside a fence, and each line that begins with three backticks opens or
# closes a fence. Its test requires every section to be under 40,000 bytes.
# No database is needed.
describe "ConceptQL.spec_path sections" do
  limit = 40_000
  lines = ConceptQL.spec_path.readlines

  sections = [ [] ]
  fence = false
  lines.each do |line|
    fence = !fence if line.start_with?("```")
    sections << [] if !fence && line.start_with?("## ")
    sections.last << line
  end

  it "balances its fence lines" do
    _(lines.count { |line| line.start_with?("```") }).must_be :even?
    _(fence).must_equal false
  end

  it "has many sections" do
    _(sections.size).must_be :>, 10
  end

  it "keeps every section under #{limit} bytes" do
    sizes = sections.to_h { |section| [ section.find { |l| l.start_with?("## ") }.to_s.strip, section.join.bytesize ] }

    _(sizes.select { |_, size| size >= limit }).must_be_empty
  end
end

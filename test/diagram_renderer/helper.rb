# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "../helper"
require_relative "svg_comparison"

# The tests of ConceptQL::DiagramRenderer, ported from the RSpec specs of the
# Jigsaw diagram editor (spec/lib/conceptql_diagram/ in the
# jigsaw-diagram-editor repository). They need no database and they need the
# resvg program (mise.toml pins it), so test/all.rb does not load them:
# `just test-diagram` runs them (test/diagram_renderer/all.rb).
#
# The references under fixtures/ are copies of the Jigsaw diagram editor's
# frontend/lib/conceptql-diagram/cli/test/fixtures/: the JavaScript renderer
# wrote them.
module DiagramRendererTest
  FIXTURES = File.expand_path("fixtures", __dir__)
  STATEMENTS = File.join(FIXTURES, "statements")

  module_function

  # The fixture directories under STATEMENTS, by name.
  def fixture_dirs = Dir.glob("**/render_tree.json", base: STATEMENTS).sort.map { File.dirname(_1) }

  # A new configuration with the gem's default asset paths, as each spec's
  # ConceptqlDiagramAssets.configure! set the editor's paths.
  def configure! = ConceptQL::DiagramRenderer.configure { |_config| nil }
end

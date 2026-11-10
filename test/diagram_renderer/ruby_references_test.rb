# frozen_string_literal: true

require_relative "helper"

# The cases that the JavaScript renderer does not have. Each fixture under
# fixtures/ruby_references has a reference that this renderer wrote, so these
# tests keep its output from changing by accident. docs/diagram_renderer.md
# says how to add one.
describe "ConceptQL::DiagramRenderer cases with Ruby references" do
  before { DiagramRendererTest.configure! }

  def fixture(*path) = File.join(DiagramRendererTest::RUBY_REFERENCES, *path)

  # The data has no Gemscript records, so the gemscript operator's counts are
  # null (bead conceptql-d1bd). Its count label says NA.
  it "draws null counts as NA" do
    tree = JSON.parse(File.read(fixture("null_counts", "render_tree.json")))
    svg = ConceptQL::DiagramRenderer.render_static(tree, show_counts: true, show_options: true)
    reference = File.read(fixture("null_counts", "reference", "static-counts-options.svg"))

    _(SvgComparison.diff(reference, SvgComparison.normalize(svg))).must_be_empty
    labels = Nokogiri::XML(svg).css(".vis-link-count tspan, .vis-link-count").map(&:text)
    _(labels.join(" ")).must_include("rows=NA")
    _(labels.join(" ")).must_include("n=NA")
  end
end

# frozen_string_literal: true

require_relative "helper"

# ConceptQL::DiagramRenderer.render_static is the Ruby port of renderStatic in
# frontend/lib/conceptql-diagram/cli/src/render-static.js. For every fixture
# under fixtures/statements, its output matches the JavaScript's
# reference/static.svg under the match rule (SvgComparison), and a fixture
# with a counts copy (fixtures/counts/<name>.json) matches
# reference/static-counts-options.svg with show_counts and show_options.
#
# It sizes the viewBox with the resvg program.
describe ConceptQL::DiagramRenderer do
  fixtures = DiagramRendererTest::FIXTURES
  statements = DiagramRendererTest::STATEMENTS
  fixture_dirs = DiagramRendererTest.fixture_dirs
  counts_dirs = fixture_dirs.select { File.exist?(File.join(fixtures, "counts", "#{File.basename(_1)}.json")) }
  shown = 10

  # The gem's asset paths.
  before { DiagramRendererTest.configure! }

  def renderer = ConceptQL::DiagramRenderer

  def load_json(file) = JSON.parse(File.read(file))

  def mismatch(name, differences, shown)
    lines = differences.first(shown).map { "  #{_1}" }
    more = differences.size > shown ? [ "  ... and #{differences.size - shown} more" ] : []
    ([ "#{name}: #{differences.size} difference(s) from the JavaScript reference" ] + lines + more).join("\n")
  end

  def view_box(svg) = Nokogiri::XML(svg).root["viewBox"].split.map(&:to_i)

  it "finds 70 fixtures, one of them with counts" do
    _(fixture_dirs.size).must_equal(70)
    _(counts_dirs).must_equal([ "jde_binary_fixture" ])
  end

  describe ".render_static" do
    fixture_dirs.each do |dir|
      it "matches reference/static.svg of #{dir}" do
        reference = File.read(File.join(statements, dir, "reference/static.svg"))
        svg = renderer.render_static(load_json(File.join(statements, dir, "render_tree.json")))
        differences = SvgComparison.diff(reference, SvgComparison.normalize(svg))
        assert_empty differences, mismatch(dir, differences, shown)
      end
    end

    counts_dirs.each do |dir|
      it "matches reference/static-counts-options.svg of #{dir} with show_counts and show_options" do
        reference = File.read(File.join(statements, dir, "reference/static-counts-options.svg"))
        tree = load_json(File.join(fixtures, "counts", "#{File.basename(dir)}.json"))
        svg = renderer.render_static(tree, show_counts: true, show_options: true)
        differences = SvgComparison.diff(reference, SvgComparison.normalize(svg))
        assert_empty differences, mismatch("#{dir} (counts, options)", differences, shown)
      end
    end

    it "writes the <style> text that is in the references" do
      svg = renderer.render_static(load_json(File.join(statements, "icd9_412/render_tree.json")))
      _(Nokogiri::XML(svg).at_css("style").text).must_equal(renderer.configuration.standalone_style_text)
    end

    it "escapes <, & and quotes in values, titles and options" do
      text = %(a<b & "c" 'd')
      node = {
        "name" => "icd9", "base" => "selection", "humanName" => text, "outputTypes" => [ "condition_occurrence" ],
        "values" => [ text ], "parameters" => { "note" => text }
      }
      document = Nokogiri::XML(renderer.render_static(node, show_options: true), &:strict)
      group = document.at_xpath("//*[@operator-type='icd9-1']")
      _(group.at_css(".vis-node-description-heading").text).must_equal(text)
      _(group.css(".vis-node-description-value").map(&:text)).must_equal([ "a<b & \"c\" 'd'", "note: #{text}" ])
    end

    it "escapes an operator name in attributes" do
      name = %(x"<&>)
      document = Nokogiri::XML(renderer.render_static({ "name" => name }), &:strict)
      icons = document.css(".vis-node-icon").map { _1.attribute_with_ns("href", ConceptQL::DiagramRenderer::Static::XLINK_NS).value }
      _(icons).must_equal([ "#operator-root", "#operator-#{name}" ])
      _(document.css(".vis-node").map { _1["operator-type"] }).must_equal([ "root-0", "#{name}-1" ])
    end
  end

  describe ".png" do
    it "draws the static SVG at its width and height" do
      tree = load_json(File.join(statements, "icd9_412/render_tree.json"))
      png = renderer.png(tree)
      _(png.byteslice(0, 8)).must_equal("\x89PNG\r\n\x1A\n".b)
      _(png.byteslice(12, 4)).must_equal("IHDR")
      _, _, width, height = view_box(renderer.render_static(tree))
      _(png.byteslice(16, 8).unpack("NN")).must_equal([ width, height ])
    end
  end
end

describe ConceptQL::DiagramRenderer::DiagramData do
  def data = ConceptQL::DiagramRenderer::DiagramData

  describe ".from" do
    node = { "name" => "icd9", "outputTypes" => [ "condition_occurrence" ], "children" => [ { "name" => "visit", "outputTypes" => [] } ] }

    it "takes a bare node, an array of statements and the conceptql-diagram/v1 wrapper alike" do
      wrapped = { "format" => "conceptql-diagram/v1", "statements" => [ node ] }
      _(data.from(node)).must_equal(data.from([ node ]))
      _(data.from(wrapped)).must_equal(data.from([ node ]))
    end

    # Not in the editor's spec: ConceptQL::Diagram.render writes symbol keys.
    it "reads symbol keys as the JSON strings they become" do
      symbols = { name: "icd9", outputTypes: [ :condition_occurrence ], children: [ { name: "visit", outputTypes: [] } ] }
      _(data.from(symbols)).must_equal(data.from(node))
      _(data.from(format: "conceptql-diagram/v1", statements: [ symbols ])).must_equal(data.from(node))
    end

    it "puts the statements under a synthetic root with path ids and defaults" do
      root = data.from([ node, { "name" => "person", "outputTypes" => [ "person" ] } ])
      _(root.slice("name", "id", "outputTypes")).must_equal({ "name" => "root", "id" => "root", "outputTypes" => %w[condition_occurrence person] })
      first = root["children"][0]
      _(first.slice("id", "parameters", "isSelected", "isAttachable")).must_equal({ "id" => "n0", "parameters" => {}, "isSelected" => false, "isAttachable" => false })
      _(first["children"][0].slice("id", "outputTypes", "children")).must_equal({ "id" => "n0.0", "outputTypes" => [ "unknown" ], "children" => [] })
      _(root["children"][1]["id"]).must_equal("n1")
    end

    {
      "a string" => [ "icd9", 'input must be a diagram node, an array of nodes, or {"format": "conceptql-diagram/v1", "statements": [...]}' ],
      "a node without a name" => [ { "values" => [] }, 'input must be a diagram node, an array of nodes, or {"format": "conceptql-diagram/v1", "statements": [...]}' ],
      "another format" => [ { "format" => "v2", "statements" => [] }, 'unsupported format "v2"; expected "conceptql-diagram/v1"' ],
      "statements without a format" => [ { "statements" => [] }, 'unsupported format undefined; expected "conceptql-diagram/v1"' ],
      "no statements" => [ [], "no statements to render" ],
      "statements that are not an array" => [ { "format" => "conceptql-diagram/v1", "statements" => {} }, "no statements to render" ],
      "a statement without a name" => [ [ node, { "name" => 1 } ], 'node n1 has no "name"' ],
      "a child that is not a node" => [ [ { "name" => "union", "children" => [ node, nil ] } ], 'node n0.1 has no "name"' ]
    }.each do |description, (input, message)|
      it "raises InputError with the JavaScript message for #{description}" do
        error = _ { data.from(input) }.must_raise(ConceptQL::DiagramRenderer::InputError)
        _(error.message).must_equal(message)
      end
    end
  end
end

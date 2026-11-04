# frozen_string_literal: true

require "open3"
require "rbconfig"
require_relative "helper"

# ConceptQL::DiagramRenderer::Geometry is a port of
# frontend/lib/conceptql-diagram/src/geometry.js. Two kinds of example:
#
# 1. For every fixture under fixtures/statements, the values in its
#    reference/geometry.json (written by cli/scripts/write-references.js from
#    the JavaScript) come out the same: numbers to 6 decimal places, strings
#    exactly, keys in the same order.
# 2. The cases of frontend/tests/unit/conceptql-diagram/geometry-test.js, with
#    the expected values worked out by hand there.
describe ConceptQL::DiagramRenderer::Geometry do
  repo = File.expand_path("../..", __dir__)
  fixtures = DiagramRendererTest::FIXTURES
  statements = DiagramRendererTest::STATEMENTS
  fixture_dirs = DiagramRendererTest.fixture_dirs

  decimals = 6

  # geometryOf in cli/scripts/write-references.js: the same values, keyed the
  # same way, from the Ruby port.
  geometry_of = lambda do |tree, has_counts|
    g = ConceptQL::DiagramRenderer::Geometry
    root = g.layout(ConceptQL::DiagramRenderer::DiagramData.from(tree))
    position = ->(h) { h.transform_keys(&:to_s) }

    nodes = root.descendants.to_h do |node|
      d = node.data
      [ d["id"], {
        "name" => d["name"], "depth" => node.depth, "dataIndex" => node.data_index, "x" => node.x, "y" => node.y,
        "nodePosition" => position.call(g.node_position(node)),
        "nodeTitle" => g.node_title(d),
        "descriptionLines" => g.description_lines(d),
        "descriptionLinesWithOptions" => g.description_lines(d, show_options: true),
        "pointColor" => g.point_color(d["outputTypes"])
      } ]
    end

    links = root.links.to_h do |link|
      output_types = link.target.data["outputTypes"]
      streams = output_types.each_with_index.map do |type, i|
        stream = { "type" => type, "streamOffset" => g.stream_offset(i), "sourceGradient" => g.source_gradient(link, i) }
        if has_counts
          stream["countLabelLines"] = g.count_label_lines(link.target.data["counts"], type)
          stream["countLabelPosition"] = position.call(g.count_label_position(link, i, output_types.length))
          stream["countLabelColor"] = g.count_label_color(type)
        end
        stream
      end
      [ link.target.data["id"], {
        "source" => link.source.data["id"],
        "connectorPath" => g.connector_path(link),
        "linkOffset" => g.link_offset(output_types),
        "insertButtonPosition" => position.call(g.insert_button_position(link)),
        "streams" => streams
      } ]
    end

    all = root.descendants
    recalls = {}
    all.select { _1.data["name"] == "recall" }.each do |recall|
      values = recall.data["values"]
      recalled = values&.any? ? all.find { _1.data.dig("parameters", "label") == values[0] } : nil
      recalls[recall.data["id"]] = { "recalled" => recalled.data["id"], "recallPath" => g.recall_path([ recall, recalled ]) } if recalled
    end

    { "nodes" => nodes, "links" => links, "recalls" => recalls }
  end

  # Every difference between the reference and the Ruby values, as
  # "path: expected ..., got ...".
  compare = lambda do |expected, actual, path, differences|
    case expected
    when Hash
      if actual.is_a?(Hash) && expected.keys == actual.keys
        expected.each { |key, value| compare.call(value, actual[key], "#{path}.#{key}", differences) }
      else
        differences << "#{path}: expected keys #{expected.keys.inspect}, got #{actual.is_a?(Hash) ? actual.keys.inspect : actual.inspect}"
      end
    when Array
      if actual.is_a?(Array) && expected.length == actual.length
        expected.each_with_index { |value, i| compare.call(value, actual[i], "#{path}[#{i}]", differences) }
      else
        differences << "#{path}: expected #{expected.inspect}, got #{actual.inspect}"
      end
    when Numeric
      unless actual.is_a?(Numeric) && expected.to_f.round(decimals) == actual.to_f.round(decimals)
        differences << "#{path}: expected #{expected.inspect}, got #{actual.inspect}"
      end
    else
      differences << "#{path}: expected #{expected.inspect}, got #{actual.inspect}" unless expected.equal?(actual) || (expected.is_a?(String) && expected == actual)
    end
    differences
  end

  it "has a reference for every fixture" do
    _(fixture_dirs.length).must_equal(70)
    fixture_dirs.each { |dir| assert File.exist?(File.join(statements, dir, "reference/geometry.json")), dir }
  end

  describe "against the JavaScript reference" do
    fixture_dirs.each do |dir|
      it "matches #{dir}/reference/geometry.json" do
        counts_file = File.join(fixtures, "counts", "#{File.basename(dir)}.json")
        has_counts = File.exist?(counts_file)
        tree = JSON.parse(File.read(has_counts ? counts_file : File.join(statements, dir, "render_tree.json")))
        expected = JSON.parse(File.read(File.join(statements, dir, "reference/geometry.json")))

        differences = compare.call(expected, geometry_of.call(tree, has_counts), "geometry", [])
        _(differences).must_be_empty(differences.first(20).join("\n"))
      end
    end
  end

  describe "the comparison" do
    # The per-fixture examples are only as good as `compare`: each case here
    # is a difference it must report.
    it "reports a number that differs in the 6th decimal, a string, a key and a length" do
      expected = { "a" => 1.000001, "b" => "M0,0", "c" => [ 1 ], "d" => { "x" => 1 }, "e" => nil }
      _(compare.call(expected, expected, "g", [])).must_be_empty
      _(compare.call(expected, expected.merge("a" => 1.000002), "g", [])).must_equal([ "g.a: expected 1.000001, got 1.000002" ])
      _(compare.call(expected, expected.merge("a" => 1.0000014), "g", [])).must_be_empty
      _(compare.call(expected, expected.merge("b" => "M0,0.0"), "g", [])).must_equal([ 'g.b: expected "M0,0", got "M0,0.0"' ])
      _(compare.call(expected, expected.merge("c" => [ 1, 2 ]), "g", [])).must_equal([ "g.c: expected [1], got [1, 2]" ])
      _(compare.call(expected, expected.merge("d" => { "y" => 1 }), "g", [])).must_equal([ 'g.d: expected keys ["x"], got ["y"]' ])
      _(compare.call(expected, expected.merge("e" => "url(#gradient-unknown)"), "g", [])).must_equal([ 'g.e: expected nil, got "url(#gradient-unknown)"' ])
    end
  end

  # The cases of frontend/tests/unit/conceptql-diagram/geometry-test.js.
  describe "geometry-test.js" do
    point = Struct.new(:x, :y, :data)

    # A link between two laid-out points; `data` mimics a hierarchy node's data.
    def link(source, target)
      ConceptQL::DiagramRenderer::TreeLayout::Link.new(
        Struct.new(:x, :y, :data).new(source[:x], source[:y], source[:data] || {}),
        Struct.new(:x, :y, :data).new(target[:x], target[:y], target[:data] || {})
      )
    end

    it "layout spaces siblings 200 apart and generations 140 apart" do
      root = ConceptQL::DiagramRenderer::Geometry.layout({ "id" => "r", "children" => [ { "id" => "a" }, { "id" => "b" } ] })
      a, b = root.children

      _([ root.x, root.y ]).must_equal([ 0, 0 ])
      _([ a.x, a.y ]).must_equal([ -100, 140 ])
      _([ b.x, b.y ]).must_equal([ 100, 140 ])
    end

    it "layout numbers nodes depth-first in input order" do
      root = ConceptQL::DiagramRenderer::Geometry.layout({ "id" => "r", "children" => [ { "id" => "a", "children" => [ { "id" => "a1" } ] }, { "id" => "b" } ] })
      by_id = root.descendants.to_h { [ _1.data["id"], _1.data_index ] }

      _(by_id).must_equal({ "r" => 0, "a" => 1, "a1" => 2, "b" => 3 })
    end

    it "diagonal_path runs from the child down to the parent top, nudged 0.01 off vertical" do
      _(ConceptQL::DiagramRenderer::Geometry.diagonal_path(link({ x: 0, y: 0 }, { x: -100, y: 140 }))).must_equal("M-100,-140v30L0.01,-20v20")
    end

    it "elbow_path enters the side of the parent" do
      _(ConceptQL::DiagramRenderer::Geometry.elbow_path(link({ x: 0, y: 0 }, { x: 100, y: 140 }))).must_equal("M100,-120v10L30,-15h-10")
    end

    it "straight_path drops vertically to the root line" do
      _(ConceptQL::DiagramRenderer::Geometry.straight_path(link({ x: 0, y: 0 }, { x: -100, y: 140 }))).must_equal("M-100,-120v10L-99.99,0")
    end

    it "connector_path picks the connector from the parent operator" do
      left = { "name" => "icd9" }
      right = { "name" => "condition_type" }
      filter = { "name" => "during", "base" => "filter", "children" => [ left, right ] }

      # Streams under the root are straight.
      _(ConceptQL::DiagramRenderer::Geometry.connector_path(link({ x: 0, y: 0, data: { "name" => "root" } }, { x: -100, y: 140, data: left })))
        .must_equal("M-100,-120v10L-99.99,0")
      # A filter's second input is an elbow.
      _(ConceptQL::DiagramRenderer::Geometry.connector_path(link({ x: 0, y: 140, data: filter }, { x: 100, y: 280, data: right })))
        .must_equal("M100,-260v10L30,-155h-10")
      # A filter's first input is a diagonal.
      _(ConceptQL::DiagramRenderer::Geometry.connector_path(link({ x: 0, y: 140, data: filter }, { x: -100, y: 280, data: left })))
        .must_equal("M-100,-280v30L0.01,-160v20")
      # Every other parent gets diagonals.
      union = { "name" => "union", "base" => "set", "children" => [ left, right ] }
      _(ConceptQL::DiagramRenderer::Geometry.connector_path(link({ x: 0, y: 140, data: union }, { x: 100, y: 280, data: right })))
        .must_equal("M100,-280v30L0.01,-160v20")
    end

    it "connector_path compares a filter's second input by identity, as === does" do
      right = { "name" => "condition_type" }
      filter = { "name" => "during", "base" => "filter", "children" => [ { "name" => "icd9" }, right ] }

      _(ConceptQL::DiagramRenderer::Geometry.connector_path(link({ x: 0, y: 140, data: filter }, { x: 100, y: 280, data: right.dup })))
        .must_equal("M100,-280v30L0.01,-160v20")
    end

    it "recall_path arcs with a radius of 0.8 x the distance" do
      # distance 50 -> radius 40
      _(ConceptQL::DiagramRenderer::Geometry.recall_path([ point.new(0, 0), point.new(30, 40) ])).must_equal("M0,0A40,40 0 0,1 30,-40")
    end

    it "link_offset centres a bundle of streams" do
      _(ConceptQL::DiagramRenderer::Geometry.link_offset([ "person" ])).must_equal(0)
      _(ConceptQL::DiagramRenderer::Geometry.link_offset(%w[person death drug_exposure])).must_equal(-5)
    end

    it "stream_offset spaces streams 5 apart" do
      _(ConceptQL::DiagramRenderer::Geometry.stream_offset(0)).must_equal(0)
      _(ConceptQL::DiagramRenderer::Geometry.stream_offset(2)).must_equal(10)
    end

    it "insert_button_position sits 66 above the parent, midway along the link" do
      one = { "outputTypes" => [ "person" ] }

      # Under the root: directly below the stream.
      _(ConceptQL::DiagramRenderer::Geometry.insert_button_position(link({ x: 0, y: 0, data: { "name" => "root" } }, { x: -100, y: 140, data: one })))
        .must_equal({ x: -100, y: -66 })
      # Midway between parent and child.
      _(ConceptQL::DiagramRenderer::Geometry.insert_button_position(link({ x: 0, y: 140, data: { "name" => "union", "base" => "set" } }, { x: -100, y: 280, data: one })))
        .must_equal({ x: -50, y: -206 })
      # A filter's right input shifts 17 right, clear of the elbow.
      _(ConceptQL::DiagramRenderer::Geometry.insert_button_position(link({ x: 0, y: 140, data: { "name" => "during", "base" => "filter" } }, { x: 100, y: 280, data: one })))
        .must_equal({ x: 67, y: -206 })
      # A three-stream bundle shifts 2 x 2.5 right.
      three = { "outputTypes" => %w[person death drug_exposure] }
      _(ConceptQL::DiagramRenderer::Geometry.insert_button_position(link({ x: 0, y: 140, data: { "name" => "union", "base" => "set" } }, { x: -100, y: 280, data: three })))
        .must_equal({ x: -45, y: -206 })
    end

    it "node_position centres the 40x40 glyph on the layout point, y flipped" do
      _(ConceptQL::DiagramRenderer::Geometry.node_position(point.new(10, 30))).must_equal({ x: -10, y: -50 })
    end

    it "source_gradient" do
      cast = { "name" => "person", "base" => "cast", "outputTypes" => %w[person death] }

      _(ConceptQL::DiagramRenderer::Geometry.source_gradient(link({ x: 0, y: 0, data: { "name" => "root" } }, { x: 0, y: 0 }), 0)).must_equal("url(#gradient-placeholder)")
      _(ConceptQL::DiagramRenderer::Geometry.source_gradient(link({ x: 0, y: 0, data: { "name" => "union" } }, { x: 0, y: 0, data: { "name" => "hidden" } }), 0)).must_equal("url(#gradient-unknown)")
      _(ConceptQL::DiagramRenderer::Geometry.source_gradient(link({ x: 0, y: 0, data: cast }, { x: 0, y: 0 }), 1)).must_equal("url(#gradient-death)")
      _(ConceptQL::DiagramRenderer::Geometry.source_gradient(link({ x: 0, y: 0, data: cast }, { x: 0, y: 0 }), 5)).must_equal("url(#gradient-unknown)")
      _(ConceptQL::DiagramRenderer::Geometry.source_gradient(link({ x: 0, y: 0, data: { "name" => "union", "base" => "set" } }, { x: 0, y: 0 }), 0)).must_be_nil
    end

    it "point_color" do
      _(ConceptQL::DiagramRenderer::Geometry.point_color([ "person" ])).must_equal("person")
      _(ConceptQL::DiagramRenderer::Geometry.point_color(%w[person death])).must_equal("mixed")
    end

    it "LINEAR_GRADIENTS covers the stream types plus placeholder and unknown" do
      _(ConceptQL::DiagramRenderer::Geometry::LINEAR_GRADIENTS.map { _1[:name] })
        .must_equal(%w[condition_occurrence death drug_exposure person placeholder procedure_cost procedure_occurrence unknown visit_occurrence])
      _(ConceptQL::DiagramRenderer::Geometry::LINEAR_GRADIENTS.find { _1[:name] == "condition_occurrence" }[:color]).must_equal("#d6758a")
    end

    describe "description_lines" do
      def v_values(count) = Array.new(count) { format("v%03d", _1) }

      it "a single value" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => [ "412" ] })).must_equal([ "412" ])
      end

      it "values that fit share one line" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => %w[250.00 250.02] })).must_equal([ "250.00, 250.02" ])
      end

      it "values spill onto the next line after 20 characters (separators not counted)" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => %w[330.0 330.1 330.2 330.3 330.8] }))
          .must_equal([ "330.0, 330.1, 330.2, 330.3", "330.8" ])
      end

      it "three full lines fit exactly with no ellipsis" do
        # 4-character values: 5 fill a 20-character line, so 3 lines hold 15.
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => v_values(15) })).must_equal([
          "v000, v001, v002, v003, v004",
          "v005, v006, v007, v008, v009",
          "v010, v011, v012, v013, v014"
        ])
      end

      it "past three lines the last line ends in an ellipsis" do
        # A 16th value has nowhere to go.
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => v_values(16) })).must_equal([
          "v000, v001, v002, v003, v004",
          "v005, v006, v007, v008, v009",
          "v010, v011, v012, v013, v014…"
        ])
      end

      it "a label takes the first line" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "parameters" => { "label" => "neuro dxs" }, "values" => [ "1" ] })).must_equal([ "neuro dxs", "1" ])
      end

      it "a long label is cut at 20 characters" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "parameters" => { "label" => "abcdefghijklmnopqrstuvwxy" }, "values" => [] }))
          .must_equal([ "abcdefghijklmnopqrst…" ])
      end

      it "a single over-long value is cut to 19 characters" do
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => [ "abcdefghijklmnopqrstuvwxy" ] })).must_equal([ "abcdefghijklmnopqrs…" ])
      end
    end

    describe "description_lines with show_options" do
      def lines(data) = ConceptQL::DiagramRenderer::Geometry.description_lines(data, show_options: true)

      it "options follow the values as key: value lines" do
        _(lines({ "values" => [], "parameters" => { "within" => "3d" } })).must_equal([ "within: 3d" ])
        _(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => [], "parameters" => { "within" => "3d" } })).must_equal([])
      end

      it "options share the 3-line limit; an ellipsis marks the ones left out" do
        _(lines({ "values" => [ "412" ], "parameters" => { "label" => "Heart", "start" => "-30d", "end" => "30d" } }))
          .must_equal([ "Heart", "412", "start: -30d…" ])
      end

      it "the label and id are never option lines; blank options are skipped" do
        _(lines({ "values" => [], "parameters" => { "id" => 5, "label" => "x" } })).must_equal([ "x" ])
        _(lines({ "values" => [], "parameters" => { "a" => nil, "b" => "", "c" => [] } })).must_equal([])
      end

      it "list options are joined; option lines run to 40 characters" do
        _(lines({ "values" => [], "parameters" => { "specialties" => %w[1 2] } })).must_equal([ "specialties: 1, 2" ])
        # A 27-character option line is shown whole.
        _(lines({ "values" => [], "parameters" => { "outpatient_minimum_gap" => "30d" } })).must_equal([ "outpatient_minimum_gap: 30d" ])
        # A 44-character option line is cut to 39 plus an ellipsis.
        _(lines({ "values" => [], "parameters" => { "outpatient_event_to_return" => "Confirming Event" } }))
          .must_equal([ "outpatient_event_to_return: Confirming…" ])
      end

      it "no options when the values already overflowed" do
        values = Array.new(16) { format("v%03d", _1) }
        _(lines({ "values" => values, "parameters" => { "within" => "3d" } }))
          .must_equal(ConceptQL::DiagramRenderer::Geometry.description_lines({ "values" => values }))
      end

      it "a single cut-off value is not overflow; options still follow" do
        _(lines({ "values" => [ "abcdefghijklmnopqrstuvwxy" ], "parameters" => { "within" => "3d" } }))
          .must_equal([ "abcdefghijklmnopqrs…", "within: 3d" ])
      end
    end

    describe "edge counts" do
      it "format_count groups thousands" do
        _(ConceptQL::DiagramRenderer::Geometry.format_count(0)).must_equal("0")
        _(ConceptQL::DiagramRenderer::Geometry.format_count(999)).must_equal("999")
        _(ConceptQL::DiagramRenderer::Geometry.format_count(1234)).must_equal("1,234")
        _(ConceptQL::DiagramRenderer::Geometry.format_count(1_234_567)).must_equal("1,234,567")
      end

      it "count_label_color matches the stream's domain, grey otherwise" do
        _(ConceptQL::DiagramRenderer::Geometry.count_label_color("condition_occurrence")).must_equal("#ad4a5b")
        _(ConceptQL::DiagramRenderer::Geometry.count_label_color("procedure_occurrence")).must_equal("#90d796")
        _(ConceptQL::DiagramRenderer::Geometry.count_label_color("person")).must_equal("#7193cd")
        _(ConceptQL::DiagramRenderer::Geometry.count_label_color("observation")).must_equal("#817980")
        _(ConceptQL::DiagramRenderer::Geometry.count_label_color(nil)).must_equal("#817980")
      end

      it "count_label_lines reads the child's counts for the stream's type" do
        counts = { "condition_occurrence" => { "rows" => 48, "n" => 37 }, "person" => { "rows" => 1200, "n" => 1200 } }
        _(ConceptQL::DiagramRenderer::Geometry.count_label_lines(counts, "condition_occurrence")).must_equal([ "rows=48", "n=37" ])
        _(ConceptQL::DiagramRenderer::Geometry.count_label_lines(counts, "person")).must_equal([ "rows=1,200", "n=1,200" ])
        _(ConceptQL::DiagramRenderer::Geometry.count_label_lines(counts, "death")).must_be_nil
        _(ConceptQL::DiagramRenderer::Geometry.count_label_lines(nil, "person")).must_be_nil
      end

      it "count_label_position sits beside the middle of the connector, outside the slope, one ascent down" do
        left = { "name" => "icd9" }
        right = { "name" => "condition_type" }
        filter = { "name" => "during", "base" => "filter", "children" => [ left, right ] }

        # Under the root: midway down the vertical run, 8 right.
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(link({ x: 0, y: 0, data: { "name" => "root" } }, { x: -100, y: 140, data: left })))
          .must_equal({ x: -92, y: -47, anchor: "start" })
        # A left child: 8 left of the midpoint, anchored at its end.
        union = { "name" => "union", "base" => "set", "children" => [ left ] }
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(link({ x: 0, y: 140, data: union }, { x: -100, y: 280, data: left })))
          .must_equal({ x: -58, y: -197, anchor: "end" })
        # A filter's right input: 8 right of the elbow run's midpoint.
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(link({ x: 0, y: 140, data: filter }, { x: 100, y: 280, data: right })))
          .must_equal({ x: 73, y: -194.5, anchor: "start" })
      end

      it "count_label_position puts each stream's label on the side nearest that stream" do
        union = { "name" => "union", "base" => "set" }
        # Midpoint of a diagonal run from (0,140) to a child at (+/-100, 280):
        # ((x + 0) / 2, (-250 + -160) / 2) = (+/-50, -205).

        # Right-leaning, 2 streams (bundle 5 wide): stream 0 left, the slope's
        # inner side, so above the midpoint; stream 1 right, the outer side,
        # one ascent below.
        right = link({ x: 0, y: 140, data: union }, { x: 100, y: 280, data: { "name" => "icd9" } })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(right, 0, 2)).must_equal({ x: 42, y: -219, anchor: "end" })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(right, 1, 2)).must_equal({ x: 58, y: -197, anchor: "start" })

        # Left-leaning, 2 streams: now the left is the outer side.
        left = link({ x: 0, y: 140, data: union }, { x: -100, y: 280, data: { "name" => "icd9" } })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(left, 0, 2)).must_equal({ x: -58, y: -197, anchor: "end" })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(left, 1, 2)).must_equal({ x: -42, y: -219, anchor: "start" })

        # Vertical run under the root: no slope, both sides hang below.
        root = link({ x: 0, y: 0, data: { "name" => "root" } }, { x: -100, y: 140, data: { "name" => "icd9" } })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(root, 0, 2)).must_equal({ x: -108, y: -47, anchor: "end" })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(root, 1, 2)).must_equal({ x: -92, y: -47, anchor: "start" })

        # 3 streams: two on the left stacking outward (upward on the inner
        # side), one on the right.
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(right, 0, 3)).must_equal({ x: 42, y: -219, anchor: "end" })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(right, 1, 3)).must_equal({ x: 37, y: -243, anchor: "end" })
        _(ConceptQL::DiagramRenderer::Geometry.count_label_position(right, 2, 3)).must_equal({ x: 58, y: -197, anchor: "start" })
      end
    end

    describe "node_title" do
      it "a title that fits is used as is" do
        _(ConceptQL::DiagramRenderer::Geometry.node_title({ "humanName" => "ICD-9 CM", "vocabularyId" => "ICD9CM" })).must_equal("ICD-9 CM")
        _("ICD-9 CM".length).must_be(:<=, ConceptQL::DiagramRenderer::Geometry::MAX_TITLE_LENGTH)
      end

      it "a too-long vocabulary title falls back to the vocabulary's ID" do
        human_name = "Logical Observation Identifiers Names and Codes (Regenstrief Institute)"
        _(ConceptQL::DiagramRenderer::Geometry.node_title({ "humanName" => human_name, "vocabularyId" => "LOINC" })).must_equal("LOINC")
      end

      it "a too-long title without a vocabulary ID is left alone" do
        human_name = "A Very Long Operator Name Indeed"
        _(ConceptQL::DiagramRenderer::Geometry.node_title({ "humanName" => human_name })).must_equal(human_name)
      end

      it "exactly MAX_TITLE_LENGTH characters still fits" do
        human_name = "x" * ConceptQL::DiagramRenderer::Geometry::MAX_TITLE_LENGTH
        _(ConceptQL::DiagramRenderer::Geometry.node_title({ "humanName" => human_name, "vocabularyId" => "X" })).must_equal(human_name)
        _(ConceptQL::DiagramRenderer::Geometry.node_title({ "humanName" => "#{human_name}x", "vocabularyId" => "X" })).must_equal("X")
      end

      it "no title stays no title" do
        _(ConceptQL::DiagramRenderer::Geometry.node_title({})).must_be_nil
      end
    end
  end

  describe "the library" do
    lib = File.join(repo, "lib")

    it "loads in a plain Ruby process with no Rails" do
      script = 'require "conceptql/diagram_renderer"; ConceptQL::DiagramRenderer::Geometry; print defined?(Rails).inspect'
      output, status = Open3.capture2e({ "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil }, RbConfig.ruby, "-I#{lib}", "-e", script)

      assert status.success?, output
      _(output).must_equal("nil")
    end

    it "references no Rails, ActiveSupport or JDE application class" do
      files = [ File.join(lib, "conceptql/diagram_renderer.rb"), *Dir.glob(File.join(lib, "conceptql/diagram_renderer/**/*.rb")) ]
      offending = files.flat_map do |file|
        File.readlines(file).each_with_index.filter_map do |line, i|
          "#{file}:#{i + 1}: #{line.strip}" if line.match?(/\b(?:Rails|ActiveSupport|ActiveRecord|ApplicationRecord)\b/)
        end
      end

      _(files.length).must_be(:>, 1)
      _(offending).must_be_empty(offending.join("\n"))
    end
  end
end

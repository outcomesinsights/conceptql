# frozen_string_literal: true

require_relative "helper"

# ConceptQL::DiagramRenderer.render_app is the Ruby port of the in-app
# drawing: renderApp in frontend/lib/conceptql-diagram/cli/src/render-static.js,
# which runs src/renderer.js in jsdom. For every fixture under
# fixtures/statements, its output matches the five reference/app*.svg files
# under the match rule (SvgComparison), with the hook attributes allowed as
# extras. The inputs are made as write-references.js makes them:
# toDiagramData, then isSelected or isAttachable on the first statement.
#
# No resvg: fit-to-view stays in the browser.
describe ConceptQL::DiagramRenderer, ".render_app" do
  fixtures = DiagramRendererTest::FIXTURES
  statements = DiagramRendererTest::STATEMENTS
  fixture_dirs = DiagramRendererTest.fixture_dirs
  hooks = %w[data-node-id data-insert-before data-diagram-key data-recall-node-ids]
  shown = 10

  # [reference file, render_app options, the change to the first statement]
  references = [
    [ "app.svg", { lock_nodes: false }, nil ],
    [ "app-locked.svg", { lock_nodes: true }, nil ],
    [ "app-summary.svg", { lock_nodes: true, summary: true }, nil ],
    [ "app-selected.svg", { lock_nodes: false }, "isSelected" ],
    [ "app-attachable.svg", { lock_nodes: false }, "isAttachable" ]
  ]

  before { DiagramRendererTest.configure! }

  def renderer = ConceptQL::DiagramRenderer

  def tree(statements, dir, mark = nil)
    data = ConceptQL::DiagramRenderer::DiagramData.from(JSON.parse(File.read(File.join(statements, dir, "render_tree.json"))))
    data["children"][0][mark] = true if mark
    data
  end

  def parse(svg) = Nokogiri::XML(svg, &:strict)

  def mismatch(name, differences, shown)
    lines = differences.first(shown).map { "  #{_1}" }
    more = differences.size > shown ? [ "  ... and #{differences.size - shown} more" ] : []
    ([ "#{name}: #{differences.size} difference(s) from the JavaScript reference" ] + lines + more).join("\n")
  end

  # Node ids in d3's descendants order, as renderer.js draws the node groups.
  def ids_in_draw_order(data) = ConceptQL::DiagramRenderer::Geometry.layout(data).descendants.map { _1.data["id"] }

  def moved?(element) = (element["class"].to_s.split & ConceptQL::DiagramRenderer::Drawing::MOVED).any?

  it "finds 70 fixtures" do
    _(fixture_dirs.size).must_equal(70)
  end

  fixture_dirs.each do |dir|
    references.each do |file, options, mark|
      it "matches reference/#{file} of #{dir}" do
        reference = File.read(File.join(statements, dir, "reference", file))
        svg = renderer.render_app(tree(statements, dir, mark), **options)
        differences = SvgComparison.diff(reference, SvgComparison.normalize(svg), allow_extra_attributes: hooks)
        assert_empty differences, mismatch("#{dir} #{file}", differences, shown)
      end
    end
  end

  it "copies the sprite as the browser serializes it: without the inherited xmlns" do
    full = File.read(File.join(fixtures, "full/icd9_412-app.svg"))
    svg = renderer.render_app(tree(statements, "icd9_412"))
    sprite = %r{<div\b[^>]*>(.*?)</div>}m
    _(svg[sprite, 1]).must_equal(full[sprite, 1])
    _(renderer.configuration.icons).must_include('<svg xmlns="http://www.w3.org/2000/svg">')
  end

  it "takes styles and icons in place of the configuration's" do
    icons = %(<svg xmlns="#{ConceptQL::DiagramRenderer::Static::SVG_NS}"><symbol id="x"/></svg>)
    svg = renderer.render_app(tree(statements, "icd9_412"), styles: "a > b { fill: red; }", icons:)
    _(parse(svg).at_css("style").text).must_equal("a > b { fill: red; }")
    _(svg).must_include(%(<div style="display: none;"><svg><symbol id="x"/></svg></div>))
  end

  describe "click hooks" do
    fixture_dirs.each do |dir|
      it "gives every node group data-node-id, and insert buttons data-insert-before only when unlocked, in #{dir}" do
        data = tree(statements, dir)
        unlocked = parse(renderer.render_app(data, lock_nodes: false))
        locked = parse(renderer.render_app(data, lock_nodes: true))

        [ unlocked, locked ].each do |document|
          _(document.css(".vis-node").map { _1["data-node-id"] }).must_equal(ids_in_draw_order(data))
        end

        links = ConceptQL::DiagramRenderer::Geometry.layout(data).links
        buttons = unlocked.css(".vis-link-new")
        _(buttons.size).must_equal(links.size)
        _(buttons.map { _1["data-insert-before"] }).must_equal(links.map { _1.target.data["id"] })
        _(locked.css(".vis-link-new").size).must_equal(links.size)
        _(locked.css("[data-insert-before]")).must_be_empty
      end
    end
  end

  describe "recall hooks" do
    def recall_ids(svg) = parse(svg).css(".vis-connect").map { JSON.parse(_1["data-recall-node-ids"]) }

    def node(name, id, parameters: {}, values: [], children: [])
      { "name" => name, "id" => id, "outputTypes" => [ "condition_occurrence" ], "parameters" => parameters,
        "values" => values, "isSelected" => false, "isAttachable" => false, "children" => children }
    end

    it "lists the recall node and the labelled node on the arc between them" do
      svg = renderer.render_app(tree(statements, "readme_ex58_recall_label"))
      _(recall_ids(svg)).must_equal([ [ "n0.0.0", "n0.0.1.0" ] ])
    end

    it "draws no arc for a recall whose label no node has" do
      svg = renderer.render_app(tree(statements, "invalid_op_and_bad_recall"))
      _(parse(svg).css(".vis-connect")).must_be_empty
    end

    it "lists on each arc every node that isRecalled matches: other recalls of the label and later nodes with it" do
      data = node("root", "root", children: [
        node("union", "a", parameters: { "label" => "L" }, children: [ node("icd9", "b", values: [ "412" ]) ]),
        node("union", "c", parameters: { "label" => "L" }),
        node("recall", "d", values: [ "L" ]),
        node("recall", "e", values: [ "L" ]),
        node("icd9", "f", parameters: { "label" => "M" })
      ])
      _(recall_ids(renderer.render_app(data))).must_equal([ %w[a c d e], %w[a c d e] ])
    end

    it "is not written without hooks" do
      drawing = ConceptQL::DiagramRenderer::Drawing.new(tree(statements, "readme_ex58_recall_label"))
      arcs = drawing.algorithm.descendants.select { _1.attributes["class"] == "vis-connect" }
      _(arcs.size).must_equal(1)
      _(arcs.first.attributes.keys).must_equal(%w[class d])
    end
  end

  describe "stable keys" do
    # Every MOVED element of the node's group and of the link to its parent.
    def keys_by_node(document)
      nodes = document.css(".vis-node").to_h { [ _1["data-node-id"], [ _1["data-diagram-key"] ] ] }
      document.css(".vis-link").each do |link|
        id = link.at_css(".vis-link-new")["data-insert-before"]
        nodes.fetch(id).concat([ link, *link.css(".vis-link-new, .vis-link-path") ].map { _1["data-diagram-key"] })
      end
      nodes
    end

    def positions(document) = document.css(".vis-node").to_h { [ _1["data-node-id"], _1["transform"] ] }

    def walk(node) = [ node, *node["children"].to_a.flat_map { walk(_1) } ]

    it "gives every MOVED element a key that is unique in the document" do
      fixture_dirs.each do |dir|
        document = parse(renderer.render_app(tree(statements, dir)))
        keys = document.xpath("//*").select { moved?(_1) }.map { _1["data-diagram-key"] }
        keys.each { |key| _(key).must_be_kind_of(String, dir) }
        _(keys.uniq.size).must_equal(keys.size, dir)
      end
    end

    it "keeps the keys of every node that stays when another node is removed" do
      data = tree(statements, "readme_ex26_filter_binary")
      before_svg = parse(renderer.render_app(data))

      # Remove the first child (and its subtree) of the first node below the
      # root that has two or more children. The ids of the others stay.
      smaller = JSON.parse(JSON.generate(data))
      parent = walk(smaller).drop(1).find { _1["children"].size >= 2 }
      removed = parent["children"].shift
      after_svg = parse(renderer.render_app(smaller))

      gone = walk(removed).map { _1["id"] }
      _(gone).wont_be_empty
      before_keys = keys_by_node(before_svg)
      after_keys = keys_by_node(after_svg)
      _(after_keys.keys.sort).must_equal((before_keys.keys - gone).sort)
      after_keys.each { |id, keys| _(keys).must_equal(before_keys.fetch(id), id) }
      # The removal moves some node that stays, so the keys are not stable by accident.
      _(positions(after_svg).reject { |id, transform| positions(before_svg)[id] == transform }).wont_be_empty
    end
  end

  describe "css_transforms" do
    translate = /\Atranslate\((?<x>[^,]+),(?<y>[^)]+)\)\z/
    css = /\Atransform: translate\((?<x>\S+)px, (?<y>\S+)px\)\z/

    def values(element) = element.attribute_nodes.to_h { [ [ _1.namespace&.href, _1.name ], _1.value ] }

    it "writes each MOVED element's transform attribute as a CSS transform, and changes nothing else" do
      fixture_dirs.each do |dir|
        data = tree(statements, dir)
        off = parse(renderer.render_app(data)).xpath("//*")
        on = parse(renderer.render_app(data, css_transforms: true)).xpath("//*")
        _(on.map(&:name)).must_equal(off.map(&:name), dir)

        off.zip(on).each do |a, b|
          if moved?(a)
            _(b["transform"]).must_be_nil
            _(b["style"]).must_match(css, "#{dir}: #{b['style'].inspect}")
            _(b["style"].match(css).named_captures).must_equal(a["transform"].match(translate).named_captures)
            _(values(b).except([ nil, "style" ])).must_equal(values(a).except([ nil, "transform" ]))
          else
            _(values(b)).must_equal(values(a))
          end
        end
      end
    end
  end
end

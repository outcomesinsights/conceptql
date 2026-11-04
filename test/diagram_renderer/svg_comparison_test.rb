# frozen_string_literal: true

require_relative "helper"

# The comparator decides whether the Ruby renderer matches the JavaScript
# reference outputs, and it can be wrong with no error. So each case below has
# an answer worked out by hand.
describe SvgComparison do
  def svg(body, root_attributes = "")
    %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"#{root_attributes}>#{body}</svg>)
  end

  def diff(expected, actual, **options)
    SvgComparison.diff(expected, actual, **options)
  end

  # [[path, message], ...], for exact expectations.
  def summary(differences)
    differences.map { |d| [ d.path, d.message ] }
  end

  let(:document) do
    svg(<<~BODY, %( class="vis" viewBox="0 0 800 500"))
      <style>.vis { font-size: 12px; }</style>
      <g class="vis-algorithm" transform="translate(10,20) scale(1.5)">
        <path class="vis-link-path-target" d="M0,-140v30L0.01,-20v20"/>
        <g class="vis-node"><use xlink:href="#operator-icd9" width="26" height="26"/><text>ICD-9 CM</text></g>
      </g>
    BODY
  end

  it "finds no difference between identical documents" do
    _(diff(document, document)).must_equal([])
  end

  fixtures = DiagramRendererTest::FIXTURES

  it "parses a committed JavaScript reference output and finds it equal to itself" do
    reference = File.read(File.join(fixtures, "statements/jde_binary_fixture/reference/app.svg"))

    _(diff(reference, reference)).must_equal([])
  end

  describe ".normalize" do
    # The digests are from sha256sum: of "a > b { x: 1 }" (the decoded text)
    # and of '<svg><symbol id="s"/></svg>' (the content as serialized). The
    # Node copy's test (cli/test/references.test.js) expects the same output.
    it "replaces the style text and the sprite content with their digests" do
      input = %(<svg xmlns="http://www.w3.org/2000/svg"><style>a &gt; b { x: 1 }</style>) +
        %(<div style="display: none;"><svg><symbol id="s"/></svg></div><g/></svg>)

      _(SvgComparison.normalize(input)).must_equal(
        %(<svg xmlns="http://www.w3.org/2000/svg">) +
        %(<style>sha256:913340a0b47f985e105f697fa76e33b64f1abfcbfdbbffb788a4b1a75f9794da</style>) +
        %(<div style="display: none;"><sprite sha256="ebfc9bbbb7d36509221a03b816633e7ca4b8212ccc152f589ad4f4dcce13f472"/></div><g/></svg>)
      )
    end

    it "gives the same style text the same digest, and a one-character change another" do
      digest = ->(css) { SvgComparison.normalize(svg("<style>#{css}</style>"))[/sha256:(\h{64})/, 1] }
      normalized = ->(css) { SvgComparison.normalize(svg("<style>#{css}</style>")) }

      _(digest.call(".vis { font-size: 12px; }")).must_equal(digest.call(".vis { font-size: 12px; }"))
      _(digest.call(".vis { font-size: 12px; }")).wont_equal(digest.call(".vis { font-size: 13px; }"))
      _(summary(diff(normalized.call(".vis { font-size: 12px; }"), normalized.call(".vis { font-size: 13px; }"))).map(&:first))
        .must_equal([ "/svg[1]/style[1]" ])
    end

    it "turns a full JavaScript SVG into its committed reference" do
      full = File.read(File.join(fixtures, "full/icd9_412-app.svg"))
      reference = File.read(File.join(fixtures, "statements/icd9_412/reference/app.svg"))
      normalized = SvgComparison.normalize(full)

      _(full.bytesize).must_be(:>, 20_000)
      _(diff(reference, normalized)).must_equal([])
      _(normalized).must_equal(reference)
    end
  end

  # As floats, these two 20-digit runs are the same number.
  it "compares digests exactly, not as numbers" do
    a = "#{"1" * 19}2#{"f" * 44}"
    b = "#{"1" * 19}3#{"f" * 44}"

    _(summary(diff(svg("<style>sha256:#{a}</style>"), svg("<style>sha256:#{b}</style>"))).map(&:first))
      .must_equal([ "/svg[1]/style[1]" ])
    _(summary(diff(svg(%(<div><sprite sha256="#{a}"/></div>)), svg(%(<div><sprite sha256="#{b}"/></div>)))).map(&:first))
      .must_equal([ "/svg[1]/div[1]/sprite[1]" ])
  end

  it "ignores attribute order" do
    expected = svg(%(<rect x="1" y="2" width="3" height="4" fill="#f4f2f3"/>))
    actual = svg(%(<rect fill="#f4f2f3" height="4" width="3" y="2" x="1"/>))

    _(diff(expected, actual)).must_equal([])
  end

  it "treats 1.0 and 1 as equal" do
    _(diff(svg(%(<rect x="1.0"/>)), svg(%(<rect x="1"/>)))).must_equal([])
  end

  # Both round to 0.123456 at 6 decimal places.
  it "treats 0.1234564 and 0.1234561 as equal" do
    _(diff(svg(%(<rect x="0.1234564"/>)), svg(%(<rect x="0.1234561"/>)))).must_equal([])
  end

  it "finds 0.123456 and 0.123457 different" do
    _(summary(diff(svg(%(<rect x="0.123456"/>)), svg(%(<rect x="0.123457"/>))))).must_equal([
      [ "/svg[1]/rect[1]", 'attribute x: expected "0.123456", got "0.123457"' ]
    ])
  end

  it "reports a missing element at its path" do
    expected = svg(%(<g><circle r="15"/><use width="20"/></g>))
    actual = svg(%(<g><circle r="15"/></g>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/g[1]/use[1]", "missing element <use> (http://www.w3.org/2000/svg)" ]
    ])
  end

  it "reports an extra element at its path" do
    expected = svg(%(<g><circle r="15"/></g>))
    actual = svg(%(<g><circle r="15"/><circle r="16"/></g>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/g[1]/circle[2]", "extra element <circle> (http://www.w3.org/2000/svg)" ]
    ])
  end

  it "reports a changed text" do
    expected = svg(%(<text class="vis-node-title">Union</text>))
    actual = svg(%(<text class="vis-node-title">Intersect</text>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/text[1]", 'text: expected "Union", got "Intersect"' ]
    ])
  end

  it "trims text before comparing it" do
    _(diff(svg(%(<text>  Union\n</text>)), svg(%(<text>Union</text>)))).must_equal([])
  end

  it "reports a changed number inside a path d string" do
    expected = svg(%(<path d="M0,-140v30L0.01,-20v20"/>))
    actual = svg(%(<path d="M0,-140v31L0.01,-20v20"/>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/path[1]", 'attribute d: expected "M0,-140v30L0.01,-20v20", got "M0,-140v31L0.01,-20v20"' ]
    ])
  end

  it "compares numbers in transform, viewBox and style values, and text, as numbers" do
    expected = svg(%(<g transform="translate(10,20)" style="font-size: 12px"><text>rows=48</text></g>), %( viewBox="0 0 800 500"))
    actual = svg(%(<g transform="translate(10.000000,20.0)" style="font-size: 12.0px"><text>rows=48.0</text></g>), %( viewBox="0.0 0 800.0 500"))

    _(diff(expected, actual)).must_equal([])
  end

  it "compares the text around numbers exactly" do
    expected = svg(%(<g transform="translate(10,20)"/>))
    actual = svg(%(<g transform="translate(10, 20)"/>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/g[1]", 'attribute transform: expected "translate(10,20)", got "translate(10, 20)"' ]
    ])
  end

  it "accepts an extra attribute it is told to allow" do
    expected = svg(%(<g class="vis-node"/>))
    actual = svg(%(<g class="vis-node" data-node-id="n0.1"/>))

    _(diff(expected, actual, allow_extra_attributes: [ "data-node-id" ])).must_equal([])
  end

  it "reports the same extra attribute when it is not allowed" do
    expected = svg(%(<g class="vis-node"/>))
    actual = svg(%(<g class="vis-node" data-node-id="n0.1"/>))

    _(summary(diff(expected, actual))).must_equal([
      [ "/svg[1]/g[1]", 'extra attribute data-node-id="n0.1"' ]
    ])
  end

  it "reports a missing attribute even when that name is allowed as an extra" do
    expected = svg(%(<g class="vis-node" data-node-id="n0.1"/>))
    actual = svg(%(<g class="vis-node"/>))

    _(summary(diff(expected, actual, allow_extra_attributes: [ "data-node-id" ]))).must_equal([
      [ "/svg[1]/g[1]", 'missing attribute data-node-id="n0.1"' ]
    ])
  end

  it "compares namespaced attributes by namespace and local name" do
    expected = svg(%(<use xlink:href="#operator-new"/>))
    actual = %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:x="http://www.w3.org/1999/xlink"><use x:href="#operator-new"/></svg>)
    plain = svg(%(<use href="#operator-new"/>))

    _(diff(expected, actual)).must_equal([])
    _(summary(diff(expected, plain))).must_equal([
      [ "/svg[1]/use[1]", 'missing attribute xlink:href="#operator-new"' ],
      [ "/svg[1]/use[1]", 'extra attribute href="#operator-new"' ]
    ])
  end

  it "reports an element of another name or namespace without descending into it" do
    expected = svg(%(<g><text>a</text></g>))
    renamed = svg(%(<text><tspan>b</tspan></text>))
    foreign = svg(%(<g xmlns="http://www.w3.org/1999/xhtml"><text>a</text></g>))

    _(summary(diff(expected, renamed))).must_equal([
      [ "/svg[1]/g[1]", "expected element <g> (http://www.w3.org/2000/svg), got <text> (http://www.w3.org/2000/svg)" ]
    ])
    _(summary(diff(expected, foreign))).must_equal([
      [ "/svg[1]/g[1]", "expected element <g> (http://www.w3.org/2000/svg), got <g> (http://www.w3.org/1999/xhtml)" ]
    ])
  end

  it "refuses a document that is not well-formed XML" do
    _ { diff(svg("<g>"), svg("")) }.must_raise(Nokogiri::XML::SyntaxError)
  end
end

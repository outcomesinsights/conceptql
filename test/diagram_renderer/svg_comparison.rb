# frozen_string_literal: true

require "digest"
require "nokogiri"

# Test-only: the match rule between the Ruby diagram renderer and the
# JavaScript reference outputs (epic jigsaw-diagram-editor-t5dq of the Jigsaw
# diagram editor; a port of its spec/support/svg_comparison.rb). Two SVG
# documents match when, after parsing, they have the same elements in the same
# order, the same attributes, and the same trimmed text, with every number
# (also inside transform, d, viewBox and style values) equal to 6 decimal
# places. Attribute order and number formatting may differ. Everything that is
# not a number is compared exactly.
#
#   SvgComparison.diff(expected_svg, actual_svg, allow_extra_attributes: ["data-node-id"])
#   # => [] when they match, else one Difference per mismatch
#
# The committed references are normalized (see normalize): compare
# normalize(ruby_svg) with the reference file.
module SvgComparison
  # `path` is the element's position, as an XPath of local names with 1-based
  # indexes among same-named siblings: /svg[1]/g[2]/path[1].
  Difference = Data.define(:path, :message) do
    def to_s = "#{path}: #{message}"
  end

  NUMBER = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/
  # split with a capture group keeps the numbers: text, number, text, ...
  SPLIT = /(#{NUMBER.source})/
  DECIMALS = 6
  SHOWN = 120
  # A digest that normalize wrote, compared exactly: as numbers, two long runs
  # of decimal digits in different digests could round to the same float.
  DIGEST = /\A(?:sha256:)?\h{64}\z/

  # normalize: the Node copy is normalizeSvg in
  # frontend/lib/conceptql-diagram/cli/scripts/write-references.js of the
  # Jigsaw diagram editor, which wrote the references.
  SPRITE = %r{<div\b([^>]*)>(.*?)</div>}m
  STYLE = %r{<style\b([^>]*)>(.*?)</style>}m
  ENTITY = /&(?:#x(\h+)|#(\d+)|(lt|gt|amp|quot|apos));/
  NAMED = { "lt" => "<", "gt" => ">", "amp" => "&", "quot" => '"', "apos" => "'" }.freeze

  module_function

  # allow_extra_attributes names attributes (qualified, e.g. "data-node-id" or
  # "xlink:href") that may exist in the actual document only.
  def diff(expected_svg, actual_svg, allow_extra_attributes: [])
    expected = parse(expected_svg).root
    actual = parse(actual_svg).root
    differences = []
    compare(expected, actual, "/#{expected.name}[1]", allow_extra_attributes.map(&:to_s), differences)
    differences
  end

  # The parts that every reference SVG repeats, copied from source files,
  # replaced by their SHA-256 digests, as the reference files hold them:
  #
  # 1. The content of the first <div> (the app's copy of the operator sprite)
  #    becomes <sprite sha256="<hex of that content, exactly as serialized>"/>.
  # 2. The text of every <style> (entities decoded) becomes sha256:<hex>.
  #
  # A string operation, not a parse, so it digests the bytes as written.
  def normalize(svg)
    svg
      .sub(SPRITE) { %(<div#{Regexp.last_match(1)}><sprite sha256="#{Digest::SHA256.hexdigest(Regexp.last_match(2))}"/></div>) }
      .gsub(STYLE) do
        attributes, raw = Regexp.last_match.captures
        "<style#{attributes}>sha256:#{Digest::SHA256.hexdigest(xml_text(raw))}</style>"
      end
  end

  # The text an XML parser reads from raw element content.
  def xml_text(raw)
    raw.gsub(ENTITY) do
      hex, decimal, name = Regexp.last_match.captures
      if hex
        hex.to_i(16).chr(Encoding::UTF_8)
      else
        decimal ? decimal.to_i.chr(Encoding::UTF_8) : NAMED.fetch(name)
      end
    end
  end

  # Equal when the non-number parts are identical and each number rounds to
  # the same value at DECIMALS places. Digests are compared exactly.
  def same_value?(expected, actual)
    return expected == actual if expected.match?(DIGEST) || actual.match?(DIGEST)

    e = pieces(expected)
    a = pieces(actual)
    e.size == a.size && e.zip(a).each_with_index.all? do |(x, y), i|
      i.odd? ? x.to_f.round(DECIMALS) == y.to_f.round(DECIMALS) : x == y
    end
  end

  # Text and numbers alternating: even indexes are text (possibly ""), odd
  # indexes are numbers.
  def pieces(value)
    value.split(SPLIT, -1)
  end

  def parse(svg)
    Nokogiri::XML(svg, &:strict)
  end

  def compare(expected, actual, path, allowed, differences)
    unless same_name?(expected, actual)
      differences << Difference.new(path, "expected element #{describe(expected)}, got #{describe(actual)}")
      return
    end

    compare_attributes(expected, actual, path, allowed, differences)

    expected_text = text_of(expected)
    actual_text = text_of(actual)
    unless same_value?(expected_text, actual_text)
      differences << Difference.new(path, "text: expected #{shorten(expected_text)}, got #{shorten(actual_text)}")
    end

    expected_children = expected.element_children
    actual_children = actual.element_children
    [ expected_children.size, actual_children.size ].max.times do |i|
      e = expected_children[i]
      a = actual_children[i]
      if e && a
        compare(e, a, child_path(path, e), allowed, differences)
      elsif e
        differences << Difference.new(child_path(path, e), "missing element #{describe(e)}")
      else
        differences << Difference.new(child_path(path, a), "extra element #{describe(a)}")
      end
    end
  end

  def compare_attributes(expected, actual, path, allowed, differences)
    e = attributes_of(expected)
    a = attributes_of(actual)
    e.each do |key, attr|
      if !a.key?(key)
        differences << Difference.new(path, "missing attribute #{qualified(attr)}=#{shorten(attr.value)}")
      elsif !same_value?(attr.value, a[key].value)
        differences << Difference.new(path, "attribute #{qualified(attr)}: expected #{shorten(attr.value)}, got #{shorten(a[key].value)}")
      end
    end
    (a.keys - e.keys).each do |key|
      attr = a[key]
      next if allowed.include?(qualified(attr))

      differences << Difference.new(path, "extra attribute #{qualified(attr)}=#{shorten(attr.value)}")
    end
  end

  # Keyed by [namespace URI, local name], so the prefix a document chose does
  # not matter.
  def attributes_of(element)
    element.attribute_nodes.to_h { |attr| [ [ attr.namespace&.href, attr.name ], attr ] }
  end

  def same_name?(expected, actual)
    expected.name == actual.name && expected.namespace&.href == actual.namespace&.href
  end

  # The element's own text (not its descendants'), trimmed.
  def text_of(element)
    element.children.select { |n| n.text? || n.cdata? }.map(&:content).join.strip
  end

  def child_path(path, element)
    index = element.parent.element_children.take_while { |n| n != element }.count { |n| n.name == element.name } + 1
    "#{path}/#{element.name}[#{index}]"
  end

  def qualified(attr)
    attr.namespace&.prefix ? "#{attr.namespace.prefix}:#{attr.name}" : attr.name
  end

  def describe(element)
    namespace = element.namespace&.href
    namespace ? "<#{element.name}> (#{namespace})" : "<#{element.name}>"
  end

  def shorten(text)
    text.length > SHOWN ? "#{text[0, SHOWN].inspect}…" : text.inspect
  end
end

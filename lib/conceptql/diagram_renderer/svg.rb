# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # SVG markup built with plain strings: an element tree, its serialization
    # with XML escaping, and the references (#id) that its elements make.
    #
    # Attribute values and text are written as the DOM writes the values that
    # renderer.js sets: a number as JavaScript's Number toString writes it
    # (JsFormat), and a nil attribute is left out (d3's attr(name, null)
    # removes the attribute). Every attribute value and text is escaped, because
    # operator names, values and options come from users.
    module Svg
      # An element: a name, attributes in the order they are written, and
      # children (Element, Raw or String text).
      Element = Data.define(:name, :attributes, :children) do
        def initialize(name:, attributes: {}, children: [])
          super(name:, attributes: attributes.reject { |_, value| value.nil? }.transform_values { JsFormat.string(_1) }, children:)
        end

        def to_s
          attrs = attributes.map { |key, value| %( #{key}="#{Svg.escape_attribute(value)}") }.join
          return "<#{name}#{attrs}/>" if children.empty?

          "<#{name}#{attrs}>#{children.map { _1.is_a?(String) ? Svg.escape_text(_1) : _1.to_s }.join}</#{name}>"
        end

        # The element's descendants in document order (querySelectorAll("*")),
        # without the element itself.
        def descendants
          children.grep(Element).flat_map { [ _1, *_1.descendants ] }
        end
      end

      # Markup copied as it is, such as an icon <symbol> from the sprite.
      Raw = Data.define(:markup) do
        def to_s = markup
      end

      # The attributes that makeStandalone (cli/src/render-static.js) reads a
      # url(#id) reference from, in the order it reads them.
      URL_ATTRIBUTES = %w[fill stroke filter clip-path mask].freeze
      URL_REFERENCE = /url\(#([^)]+)\)/

      module_function

      def element(name, attributes = {}, children = []) = Element.new(name:, attributes:, children:)

      # The ids that one element's attributes refer to, in the order
      # makeStandalone finds them: the href (xlink:href, else href), then a
      # url(#id) in each of URL_ATTRIBUTES. attributes is a hash of qualified
      # names to values.
      def references(attributes)
        href = [ attributes["xlink:href"], attributes["href"] ].find { _1 && !_1.empty? }
        refs = href&.start_with?("#") ? [ href[1..] ] : []
        refs + URL_ATTRIBUTES.filter_map { attributes[_1]&.match(URL_REFERENCE)&.[](1) }
      end

      # An attribute value as XMLSerializer escapes it. The tab, newline and
      # carriage return are character references, so a parser reads them back
      # unchanged (it would read a raw one as a space).
      def escape_attribute(value)
        value.gsub(/[&<>"\t\n\r]/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "\t" => "&#x9;", "\n" => "&#xA;", "\r" => "&#xD;")
      end

      # Text as XMLSerializer escapes it. A carriage return is a character
      # reference, so a parser does not turn it into a newline.
      def escape_text(text)
        text.gsub(/[&<>\r]/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\r" => "&#xD;")
      end
    end
  end
end

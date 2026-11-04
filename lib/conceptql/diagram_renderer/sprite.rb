# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # The operator icon sprite: markup that holds <symbol id="operator-..">
    # elements, which the drawing's <use> elements refer to. The gem's copy,
    # assets/diagram/operators.svg, is the content of the hidden
    # <div class="operators"> of frontend/index.html. The markup may also be a
    # whole HTML page: only the elements with an id matter.
    #
    # The sprite is read with a small tag scanner, not an XML parser (the
    # library uses the standard library only). It expects well-formed markup
    # with quoted attribute values, as the sprite is. Each element with an id
    # keeps its markup exactly as written, for copying into an SVG.
    class Sprite
      TAG = %r{
        <!--.*?-->
        | <!\[CDATA\[.*?\]\]>
        | <[!?][^>]*>
        | </(?<close>[^\s>]+)\s*>
        | <(?<open>[^\s/>]+)(?<attributes>(?:[^>"']|"[^"]*"|'[^']*')*?)(?<empty>/?)>
      }mx
      ATTRIBUTE = /([^\s=]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

      # One element with an id: where its start tag is, its markup, and the ids
      # its descendants refer to (Svg.references of each, in document order).
      Entry = Data.define(:at, :markup, :references)

      def initialize(markup)
        @entries = {}
        scan(markup)
      end

      def key?(id) = @entries.key?(id)

      # The markup of the element with this id.
      def markup(id) = @entries.fetch(id).markup

      # The ids that the element's descendants refer to.
      def references(id) = @entries.fetch(id).references

      private

      # As querySelectorAll("[id]") into a Map: when two elements share an id,
      # the later one (in document order) wins.
      def scan(markup)
        open = []
        tags = []
        markup.scan(TAG) do
          match = Regexp.last_match
          if match[:open]
            attributes = match[:attributes].scan(ATTRIBUTE).to_h { |name, double, single| [ name, double || single ] }
            tag = { at: match.begin(0), id: attributes["id"], references: Svg.references(attributes) }
            tags << tag
            match[:empty].empty? ? open.push([ match[:open], tag ]) : record(markup, tag, tags, match.end(0))
          elsif match[:close]
            index = open.rindex { |name, _| name == match[:close] } or next
            _, tag = open.slice!(index..).first
            record(markup, tag, tags, match.end(0))
          end
        end
      end

      def record(markup, tag, tags, finish)
        return unless tag[:id]
        return if @entries[tag[:id]] && @entries[tag[:id]].at > tag[:at]

        inner = tags.select { |t| t[:at] > tag[:at] && t[:at] < finish }.flat_map { _1[:references] }
        @entries[tag[:id]] = Entry.new(at: tag[:at], markup: markup[tag[:at]...finish], references: inner)
      end
    end
  end
end

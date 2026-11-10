# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # The geometry and presentation rules of the diagram: layout, connector
    # paths, offsets, colours and label packing. A port of
    # frontend/lib/conceptql-diagram/src/geometry.js. The JavaScript file is the
    # reference: every fixture's reference/geometry.json comes from it, and
    # test/diagram_renderer/geometry_test.rb compares the two. Each method
    # names the JavaScript function it ports.
    #
    # Input is a diagram tree as hashes with string keys ("id", "name", "base",
    # "humanName", "outputTypes", "values", "parameters", "children", "counts").
    # A node, as `layout` returns it and the link methods take it, has `x`, `y`
    # and `data` (a TreeLayout::Node); a link has `source` (the parent) and
    # `target` (the child). Positions are hashes with symbol keys.
    #
    # Coordinates: the tree layout puts depth along +y. The diagram draws the
    # root at the bottom and grows upward, so every y is negated when drawn.
    module Geometry
      extend self

      # NODE_SPACING
      NODE_SPACING = { x: 200, y: 140 }.freeze

      # LINEAR_GRADIENTS: the colour of each stream type, for link source
      # gradients.
      LINEAR_GRADIENTS = [
        { name: "condition_occurrence", color: "#d6758a" },
        { name: "death", color: "#a7736f" },
        { name: "drug_exposure", color: "#cf92d2" },
        { name: "person", color: "#a9c9e7" },
        { name: "placeholder", color: "#f6f3f5" },
        { name: "procedure_cost", color: "#e0d67f" },
        { name: "procedure_occurrence", color: "#a7e2ac" },
        { name: "unknown", color: "#958c93" },
        { name: "visit_occurrence", color: "#e8d4b3" }
      ].map(&:freeze).freeze

      CHARACTERS_PER_LINE = 20
      # Option lines ("key: value") may run wider than values: a key cut at 20
      # characters loses the value readers need (Ryan, 2026-09-24).
      OPTION_CHARACTERS_PER_LINE = 40
      MAX_DESCRIPTION_LINES = 3
      ELLIPSIS = "…"

      # MAX_TITLE_LENGTH: the longest node title (12px bold) that stays clear of
      # the next node's title.
      MAX_TITLE_LENGTH = 22

      # Parameters that are never shown as option lines: the label already
      # heads the description, and the id is bookkeeping.
      HIDDEN_OPTIONS = %w[label id].freeze

      # COUNT_LABEL: the styling of edge-count labels, the grey of the spec's
      # GraphViz diagrams.
      COUNT_LABEL = { fill: "#817980", font_size: 10, line_height: 12, ascent: 8, gap: 8 }.freeze

      # Each stream's count label is coloured like its domain's node glyph (the
      # colours of diagram_styles.css .vis-node-point[data-color]).
      DOMAIN_LABEL_COLORS = {
        "condition_occurrence" => "#ad4a5b",
        "death" => "#704a4a",
        "drug_exposure" => "#9f57a5",
        "observation_period" => "#6fbbba",
        "person" => "#7193cd",
        "procedure_occurrence" => "#90d796",
        "visit_occurrence" => "#d1a776"
      }.freeze

      # layout: lays the tree out with d3.tree() (TreeLayout). Returns the root
      # TreeLayout::Node with x and y on every node, and a depth-first pre-order
      # data_index in input order.
      def layout(data)
        root = TreeLayout.hierarchy(data) { _1["children"] }

        index = 0
        root.each_before do |node|
          node.data_index = index
          index += 1
        end

        TreeLayout.new(node_size: [ NODE_SPACING[:x], NODE_SPACING[:y] ], separation: ->(_a, _b) { 1 }).call(root)
      end

      # diagonalPath: the connector from a child (target) down to its parent
      # (source). The +0.01 keeps the path from being perfectly vertical: a
      # zero-width bounding box would make the objectBoundingBox gradient on the
      # source path render as nothing.
      def diagonal_path(link)
        path("M", link.target.x, ",", -link.target.y, "v30L", link.source.x + 0.01, ",", -link.source.y - 20, "v20")
      end

      # elbowPath: the right-hand input of a filter enters the filter's side.
      def elbow_path(link)
        path("M", link.target.x, ",", -link.target.y + 20, "v10L", link.source.x + 30, ",", -link.source.y - 15, "h-10")
      end

      # straightPath: streams under the (invisible) root run straight down.
      def straight_path(link)
        path("M", link.target.x, ",", -link.target.y + 20, "v10L", link.target.x + 0.01, ",", -link.source.y)
      end

      # connectorPath: the connector for a link, by the shape of the source
      # (parent) operator.
      def connector_path(link)
        if root?(link.source.data)
          straight_path(link)
        elsif second_filter_input?(link)
          elbow_path(link)
        else
          diagonal_path(link)
        end
      end

      # recallPath: the arc from a recall node to the node it recalls.
      def recall_path((from, to))
        dx = to.x - from.x
        dy = to.y - from.y
        dr = Math.sqrt((dx * dx) + (dy * dy)) * 0.8
        path("M", from.x, ",", -from.y, "A", dr, ",", dr, " 0 0,1 ", to.x, ",", -to.y)
      end

      # linkOffset: more streams make a wider link bundle, so shift it left to
      # stay centred.
      def link_offset(target_output_types)
        (target_output_types.length - 1) * -2.5
      end

      # streamOffset: each stream in a bundle sits 5px right of the previous one.
      def stream_offset(index)
        index * 5
      end

      # insertButtonPosition: the position of a link's "+" insert button,
      # relative to the link group.
      def insert_button_position(link)
        source = link.source.data
        output_types = link.target.data["outputTypes"]
        x = link.source.x + ((output_types.length - 1) * 2.5)
        y = -link.source.y - 66

        if root?(source)
          x = link.target.x
        else
          x += (link.target.x - link.source.x) / 2.0
        end

        x += 17 if source["base"] == "filter" && link.target.x > link.source.x

        { x:, y: }
      end

      # nodePosition: the top-left of a node's 40x40 glyph box, centred on its
      # layout point.
      def node_position(node)
        { x: node.x - 20, y: -node.y - 20 }
      end

      # sourceGradient: the stroke of a link's source-side path. Placeholder
      # under the root, unknown into a hidden node, the cast's own type for
      # casts, otherwise nil (the CSS data-color on the target path supplies the
      # colour).
      def source_gradient(link, stream_index)
        source = link.source.data
        target = link.target.data

        if root?(source)
          "url(#gradient-placeholder)"
        elsif target["name"] == "hidden"
          "url(#gradient-unknown)"
        elsif source["base"] == "cast"
          type = source["outputTypes"][stream_index]
          "url(#gradient-#{JsFormat.truthy?(type) ? JsFormat.string(type) : 'unknown'})"
        end
      end

      # pointColor: a node's glyph colour key, its single stream type or
      # "mixed".
      def point_color(output_types)
        output_types.length == 1 ? output_types[0] : "mixed"
      end

      # nodeTitle: a node's title. Its humanName, unless that is longer than
      # MAX_TITLE_LENGTH and the node is a vocabulary operator: then its
      # vocabulary ID (e.g. "LOINC" rather than "Logical Observation Identifiers
      # Names and Codes (Regenstrief Institute)").
      def node_title(data)
        title = data["humanName"]
        vocabulary_id = data["vocabularyId"]
        return vocabulary_id if title.is_a?(String) && title.length > MAX_TITLE_LENGTH && JsFormat.truthy?(vocabulary_id)

        title
      end

      # descriptionLines: the lines under a node's heading. The label (if any)
      # first, cut at 20 characters, then the values packed 20 characters to a
      # line, 3 lines in all. A single over-long value is cut to 19 characters
      # plus an ellipsis, and when values overflow the last line the ellipsis
      # marks the cut.
      #
      # With show_options, the node's options follow as "key: value" lines, each
      # cut at 40 characters, within the same 3-line limit. If they do not all
      # fit, the last shown line ends in an ellipsis.
      def description_lines(data, show_options: false)
        display, overflowed = value_lines(data)
        return display if !show_options || overflowed

        parameters = data["parameters"]
        parameters = {} unless JsFormat.truthy?(parameters)
        options = JsFormat.entries(parameters)
          .reject { |key, value| HIDDEN_OPTIONS.include?(key) || blank?(value) }
          .map { |key, value| truncate_line("#{key}: #{value.is_a?(Array) ? JsFormat.join(value, ', ') : JsFormat.string(value)}", OPTION_CHARACTERS_PER_LINE) }

        options.each do |option|
          if display.length == MAX_DESCRIPTION_LINES
            display[-1] += ELLIPSIS unless display[-1].end_with?(ELLIPSIS)
            break
          end
          display.push(option)
        end
        display
      end

      # countLabelColor: the text colour of a stream's count label, grey for
      # other domains.
      def count_label_color(stream_type)
        DOMAIN_LABEL_COLORS.fetch(stream_type, COUNT_LABEL[:fill])
      end

      # formatCount: 1234567 becomes "1,234,567". A null count is NA: the
      # data has no records of the operator's vocabulary (bead
      # conceptql-d1bd). The JavaScript renderer has no such case, so the
      # reference of a null count comes from this renderer.
      def format_count(n)
        return "NA" if n.nil?

        JsFormat.string(n).gsub(/\B(?=(\d{3})+(?!\d))/, ",")
      end

      # countLabelLines: the two label lines for one stream, from the child
      # node's counts[<stream type>] = { "rows", "n" }; nil when there is
      # nothing to show.
      def count_label_lines(counts, stream_type)
        c = JsFormat.truthy?(counts) ? counts[stream_type] : nil
        return nil unless c.is_a?(Hash) && c.key?("rows") && c.key?("n")

        [ "rows=#{format_count(c['rows'])}", "n=#{format_count(c['n'])}" ]
      end

      # countLabelPosition: where a stream's count label sits, in its stream
      # group's coordinates, beside the midpoint of the connector's sloped (or,
      # under the root, vertical) run.
      #
      # One stream: on the outside of the slope, to the left (anchored at its
      # end) when the child is left of its parent, otherwise to the right.
      #
      # Several streams (drawn side by side, stream 0 leftmost): each label goes
      # on the side of the bundle nearest its own stream, so the left half of
      # the streams label on the left and the rest on the right, stacking
      # outward from the midpoint.
      #
      # On the outer side of the slope the connector rises away from the label,
      # so the label hangs one ascent below the midpoint. On the inner side the
      # connector falls away beneath it, so the label sits just above.
      def count_label_position(link, stream_index = 0, stream_count = 1)
        source = link.source.data
        from = [ link.target.x, -link.target.y + 30 ]
        to =
          if root?(source)
            [ link.target.x, -link.source.y ]
          elsif second_filter_input?(link)
            [ link.source.x + 30, -link.source.y - 15 ]
          else
            [ link.source.x, -link.source.y - 20 ]
          end
        mid_x = (from[0] + to[0]) / 2.0
        mid_y = (from[1] + to[1]) / 2.0

        sloped = !root?(source) && link.target.x != link.source.x
        outer = link.target.x < link.source.x ? "left" : "right"

        if stream_count <= 1
          side = sloped ? outer : "right"
          stack = 0
        else
          left_count = (stream_count / 2.0).ceil
          side = stream_index < left_count ? "left" : "right"
          stack = side == "left" ? stream_index : stream_index - left_count
        end
        inner = sloped && side != outer

        # Each label is drawn inside its own stream's group, already shifted
        # stream_offset(i) right. Cancel that so labels line up just outside the
        # bundle's left or right edge.
        own_shift = stream_offset(stream_index)
        bundle_width = stream_offset(stream_count - 1)
        label_height = 2 * COUNT_LABEL[:line_height]

        {
          x: side == "left" ? mid_x - COUNT_LABEL[:gap] - own_shift : mid_x + COUNT_LABEL[:gap] + bundle_width - own_shift,
          y: inner ? mid_y - 2 - COUNT_LABEL[:line_height] - (stack * label_height) : mid_y + COUNT_LABEL[:ascent] + (stack * label_height),
          anchor: side == "left" ? "end" : "start"
        }
      end

      private

      # A path string: numbers written as JavaScript writes them.
      def path(*parts)
        parts.map { _1.is_a?(String) ? _1 : JsFormat.number(_1) }.join
      end

      def root?(data) = data["name"] == "root"

      # The link enters a filter as the filter's second (right-hand) input. The
      # JavaScript compares the child object itself (===), so this compares
      # identity.
      def second_filter_input?(link)
        source = link.source.data
        source["base"] == "filter" && JsFormat.truthy?(source["children"]) && source["children"][1].equal?(link.target.data)
      end

      # isBlank
      def blank?(value)
        value.nil? || value == "" || value == []
      end

      # truncateLine: cut a line to `limit` characters, ellipsis included,
      # without leaving a space before the ellipsis.
      def truncate_line(text, limit)
        text.length > limit ? JsFormat.trim_end(text[0, limit - 1]) + ELLIPSIS : text
      end

      # valueLines: the label and value packing JDE has always drawn. Returns
      # [lines, overflowed]; overflowed means values were cut off because the
      # lines ran out.
      def value_lines(data)
        lines = MAX_DESCRIPTION_LINES
        overflowed = false
        characters_remaining = CHARACTERS_PER_LINE
        display = []
        line = []
        values = data["values"]
        values = JsFormat.truthy?(values) ? values.dup : []

        # If there is a label, cut it and make it the first line.
        parameters = data["parameters"]
        if JsFormat.truthy?(parameters) && JsFormat.truthy?(parameters["label"])
          label_text = parameters["label"]
          label_text = label_text[0, CHARACTERS_PER_LINE] + ELLIPSIS if JsFormat.length(label_text) > CHARACTERS_PER_LINE
          display.push(label_text)
          lines -= 1
        end

        # Now split the values into lines by the space available. The loop ends
        # at the first falsy value, as `while ((value = values.pop()))` does.
        values.reverse!
        while JsFormat.truthy?(value = values.pop)
          if JsFormat.length(value) > CHARACTERS_PER_LINE
            value = value[0, CHARACTERS_PER_LINE - 1] + ELLIPSIS
          elsif JsFormat.length(value) > characters_remaining
            display.push(JsFormat.join(line, ", "))
            lines -= 1
            if lines.positive?
              characters_remaining = CHARACTERS_PER_LINE
              line = []
            else
              display[-1] += ELLIPSIS
              overflowed = true
              break
            end
          end

          line.push(value)
          characters_remaining -= JsFormat.length(value)

          display.push(JsFormat.join(line, ", ")) if values.empty?
        end

        [ display, overflowed ]
      end
    end
  end
end

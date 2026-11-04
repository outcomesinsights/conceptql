# frozen_string_literal: true

require "json"

module ConceptQL
  module DiagramRenderer
    # The drawing that frontend/lib/conceptql-diagram/src/renderer.js makes on
    # its first update(), at duration 0: the stream gradients for <defs> and the
    # <g class="vis-algorithm"> group with the links, the nodes and the recall
    # arcs. Elements, attributes and their order are the renderer's. Each
    # method names the renderer.js method it ports. lockNodes changes only the
    # class of the root svg, which the caller writes.
    #
    # data is a diagram tree with ids (DiagramData.from makes one).
    #
    # Two options serve the in-app SVG (App). They write what renderer.js does
    # with event handlers and transitions:
    #
    # - hooks: each node group gets data-node-id (the element that onNodeClick
    #   listens on), and each "+" insert button gets data-insert-before (the
    #   element that onInsertBefore listens on) unless lock_nodes is true. Each
    #   element that a transition moves (MOVED) gets data-diagram-key, made
    #   from node ids as the D3 joins key them, so it is the same in every
    #   render of the same node. Each recall arc (.vis-connect) gets
    #   data-recall-node-ids, a JSON array of the ids of the nodes whose
    #   mouseenter shows the arcs (see recall_node_ids).
    # - css_transforms: each MOVED element's position is written as
    #   style="transform: translate(Xpx, Ypx)" and not as the transform
    #   attribute, because CSS transitions cannot animate the attribute.
    class Drawing
      # The classes of the elements whose transform renderer.js transitions.
      MOVED = %w[vis-link vis-link-new vis-link-path vis-node].freeze

      attr_reader :data, :show_counts, :show_options

      def initialize(data, show_counts: false, show_options: false, hooks: false, lock_nodes: true, css_transforms: false)
        @data = data
        @show_counts = show_counts
        @show_options = show_options
        @hooks = hooks
        @lock_nodes = lock_nodes
        @css_transforms = css_transforms
        root = Geometry.layout(data)
        @nodes = root.descendants
        @links = root.links
      end

      # updateLinearGradients
      def gradients
        Geometry::LINEAR_GRADIENTS.map do |gradient|
          stops = [ [ "5%", 0 ], [ "95%", 1 ] ].map do |offset, opacity|
            Svg.element("stop", { "offset" => offset, "stop-color" => gradient[:color], "stop-opacity" => opacity })
          end
          Svg.element("linearGradient", { "x1" => 0, "x2" => 0, "y1" => 0, "y2" => 1, "id" => "gradient-#{gradient[:name]}" }, stops)
        end
      end

      # updateTree: the links, then the nodes, then the recall arcs.
      def algorithm
        children = @links.map { link(_1) } + @nodes.map { node(_1) } + recall_connections.map { recall(_1) }
        Svg.element("g", { "class" => "vis-algorithm", "data-test-diagram-group" => "" }, children)
      end

      private

      # updateLinks, for one link.
      def link(link)
        target = link.target.data
        streams = target["outputTypes"].each_with_index.map { |type, i| stream(link, type, i) }
        attributes = { "class" => "vis-link", **place(Geometry.link_offset(target["outputTypes"]), 0), **key("link:#{link_key(link)}") }
        Svg.element("g", attributes, streams + [ insert_button(link) ])
      end

      # The "+" insert button of a link (.vis-link-new).
      def insert_button(link)
        classes = [ "vis-link-new" ]
        classes << "is-selectable" if JsFormat.truthy?(link.target.data["isAttachable"])
        position = Geometry.insert_button_position(link)
        text = link.source.data["name"] == "root" && link.target.data["name"] == "hidden" ? [ "New Stream" ] : []
        attributes = { "class" => classes.join(" "), **place(position[:x], position[:y]), **key("link-new:#{link_key(link)}") }
        attributes["data-insert-before"] = link.target.data["id"] if @hooks && !@lock_nodes
        Svg.element("g", attributes, [
          Svg.element("circle", { "r" => 15 }),
          Svg.element("use", { "xlink:href" => "#operator-new", "height" => 20, "width" => 20, "x" => -10, "y" => -10 }),
          Svg.element("text", { "class" => "vis-link-text", "x" => 30, "y" => 1 }, text)
        ])
      end

      # One stream of a link (.vis-link-path): the target and source paths and,
      # with show_counts, the count label.
      def stream(link, type, index)
        path = Geometry.connector_path(link)
        color = link.target.data["name"] == "hidden" ? "placeholder" : type
        children = [
          Svg.element("path", { "class" => "vis-link-path-target", "data-color" => color, "d" => path }),
          Svg.element("path", { "class" => "vis-link-path-source", "stroke" => Geometry.source_gradient(link, index), "d" => path })
        ]
        children << count_label(link, type, index) if show_counts
        attributes = { "class" => "vis-link-path", **place(Geometry.stream_offset(index), 0), **key("link-path:#{link_key(link)}:#{index}") }
        Svg.element("g", attributes, children)
      end

      def count_label(link, type, index)
        target = link.target.data
        lines = Geometry.count_label_lines(target["counts"], type) || []
        position = Geometry.count_label_position(link, index, target["outputTypes"].length)
        tspans = lines.each_with_index.map do |line, j|
          Svg.element("tspan", { "x" => 0, "dy" => j.zero? ? 0 : Geometry::COUNT_LABEL[:line_height] }, [ line ])
        end
        Svg.element("text", {
          "class" => "vis-link-count",
          "transform" => translate(position[:x], position[:y]),
          "text-anchor" => position[:anchor],
          "fill" => Geometry.count_label_color(type),
          "font-size" => Geometry::COUNT_LABEL[:font_size]
        }, tspans)
      end

      # updateNodes, for one node.
      def node(node)
        d = node.data
        label = label?(d)
        classes = [ "vis-node" ]
        classes << "is-active" if JsFormat.truthy?(d["isSelected"])
        classes << "is-error" unless empty?(d["errors"])
        classes << "is-warning" unless empty?(d["warnings"])
        classes << "is-label" if label
        position = Geometry.node_position(node)

        attributes = {
          "operator-type" => "#{d['name']}-#{node.data_index}",
          "class" => classes.join(" "),
          "data-test-node" => "",
          **place(position[:x], position[:y])
        }
        attributes.merge!("data-node-id" => d["id"], **key("node:#{JsFormat.string(d['id'])}")) if @hooks
        Svg.element("g", attributes, [
          Svg.element("use", { "class" => "vis-node-point", "height" => 40, "width" => 40, "data-color" => Geometry.point_color(d["outputTypes"]), "xlink:href" => "#operator-base-#{template(d, 'base')}" }),
          Svg.element("use", { "class" => "vis-node-icon", "height" => 26, "width" => 26, "transform" => "translate(7,7)", "xlink:href" => "#operator-#{d['name']}" }),
          Svg.element("use", { "class" => "vis-node-label", "xlink:href" => "#operator-label", "height" => 8, "width" => 10, "transform" => "translate(45, 32)" }),
          badge("vis-node-warning", "#operator-warning"),
          badge("vis-node-error", "#operator-error"),
          description(d, label)
        ])
      end

      # The warning and error badges, which CSS shows on .is-warning and
      # .is-error nodes.
      def badge(name, href)
        Svg.element("g", { "class" => name }, [
          Svg.element("circle", { "r" => 12 }),
          Svg.element("use", { "xlink:href" => href, "height" => 22, "width" => 22, "transform" => "translate(-11,-11)" })
        ])
      end

      # The title and the description lines. A labelled node's first value
      # line is indented past the label icon.
      def description(data, label)
        title = Geometry.node_title(data)
        heading = Svg.element("tspan", { "class" => "vis-node-description-heading", "style" => "font-size: 12px;" }, text(title))
        values = Geometry.description_lines(data, show_options:).each_with_index.map do |line, i|
          Svg.element("tspan", {
            "class" => "vis-node-description-value",
            "style" => "font-size: 10px;",
            "x" => label && i.zero? ? 15 : 0,
            "y" => "#{JsFormat.number(((i + 1) * 1.4) + 0.2)}em"
          }, text(line))
        end
        Svg.element("text", { "class" => "vis-node-description", "transform" => "translate(45,21)" }, [ heading, *values ])
      end

      # updateRecalls, for one recall arc.
      def recall(connection)
        attributes = { "class" => "vis-connect", "d" => Geometry.recall_path(connection) }
        attributes["data-recall-node-ids"] = JSON.generate(recall_node_ids(connection)) if @hooks
        Svg.element("path", attributes)
      end

      # The ids of the nodes for which isRecalled finds this arc. renderer.js
      # shows every arc on the mouseenter of such a node. A recall node
      # compares its first value, and any other node its label when that is
      # truthy, with the first value of the arc's recall.
      def recall_node_ids(connection)
        value = connection[0].data["values"][0]
        nodes = @nodes.select do |node|
          d = node.data
          if d["name"] == "recall"
            values = d["values"]
            (values.is_a?(Array) || values.is_a?(String)) && !values.empty? && same?(values[0], value)
          else
            label?(d) && same?(d["parameters"]["label"], value)
          end
        end
        nodes.map { JsFormat.string(_1.data["id"]) }
      end

      # recallConnections: each recall node with the first node (in
      # descendants order) whose label is the recall's first value.
      def recall_connections
        @nodes.filter_map do |recall|
          values = recall.data["values"]
          next unless recall.data["name"] == "recall" && !empty?(values)

          recalled = @nodes.find do |node|
            parameters = node.data["parameters"]
            parameters.is_a?(Hash) && parameters.key?("label") && same?(parameters["label"], values[0])
          end
          [ recall, recalled ] if recalled
        end
      end

      # The is-label class: `params && params.label`.
      def label?(data)
        parameters = data["parameters"]
        parameters.is_a?(Hash) && JsFormat.truthy?(parameters["label"])
      end

      # isEmpty in renderer.js: nil, an empty string or array, or an object
      # whose length is 0.
      def empty?(value)
        case value
        when nil then true
        when String, Array then value.empty?
        when Hash then value["length"].is_a?(Numeric) && value["length"].zero?
        else false
        end
      end

      # JavaScript ===: arrays and objects are equal only to themselves.
      def same?(a, b) = a.is_a?(Array) || a.is_a?(Hash) ? a.equal?(b) : a == b

      # A key in a template literal: a missing key is "undefined".
      def template(data, key) = data.key?(key) ? JsFormat.string(data[key]) : "undefined"

      # d3's text(value): nil is no text.
      def text(value) = value.nil? ? [] : [ JsFormat.string(value) ].reject(&:empty?)

      def translate(x, y) = "translate(#{JsFormat.number(x)},#{JsFormat.number(y)})"

      # The position of a MOVED element: the transform attribute or, with
      # css_transforms, the same translation as a CSS transform.
      def place(x, y)
        return { "transform" => translate(x, y) } unless @css_transforms

        { "style" => "transform: translate(#{JsFormat.number(x)}px, #{JsFormat.number(y)}px)" }
      end

      # The data-diagram-key attribute of a MOVED element, with hooks.
      def key(value) = @hooks ? { "data-diagram-key" => value } : {}

      # The D3 join key of a link (updateTree): "<source id>-<target id>".
      def link_key(link) = "#{JsFormat.string(link.source.data['id'])}-#{JsFormat.string(link.target.data['id'])}"
    end
  end
end

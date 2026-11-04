# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # A standalone static SVG of a diagram: renderStatic in
    # frontend/lib/conceptql-diagram/cli/src/render-static.js. The Drawing,
    # then makeStandalone (inline the sprite symbols the drawing uses, add the
    # <style>) and fitToContent (a viewBox around the drawing, measured by
    # resvg, and a background rect).
    #
    #   ConceptQL::DiagramRenderer::Static.new(configuration).render(input) # => SVG text
    class Static
      PADDING = 24
      BACKGROUND = "#f4f2f3"
      SVG_NS = "http://www.w3.org/2000/svg"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      # The canvas that fitToContent measures on: larger than any diagram.
      MEASURE = [ -5000, -5000, 10_000, 10_000 ].freeze

      def initialize(configuration)
        @configuration = configuration
      end

      def render(input, show_counts: false, show_options: false)
        drawing = Drawing.new(DiagramData.from(input), show_counts:, show_options:)
        algorithm = drawing.algorithm
        style = Svg.element("style", {}, [ @configuration.standalone_style_text ])
        defs = Svg.element("defs", {}, drawing.gradients + symbols(algorithm))

        x, y, width, height = @configuration.resvg.bbox(root(MEASURE, [ style, defs, algorithm ]).to_s)
        raise "the diagram rendered nothing measurable" unless width.positive? && height.positive?

        view_box = [ (x - PADDING).floor, (y - PADDING).floor, (width + (2 * PADDING)).ceil, (height + (2 * PADDING)).ceil ]
        background = Svg.element("rect", { "x" => view_box[0], "y" => view_box[1], "width" => view_box[2], "height" => view_box[3], "fill" => BACKGROUND })
        root(view_box, [ style, defs, background, algorithm ]).to_s
      end

      private

      def root(view_box, children)
        Svg.element("svg", {
          "xmlns" => SVG_NS,
          "xmlns:xlink" => XLINK_NS,
          "class" => "vis is-new",
          "viewBox" => view_box.join(" "),
          "width" => view_box[2],
          "height" => view_box[3]
        }, children)
      end

      # The sprite elements the drawing refers to, and those they refer to, in
      # the order makeStandalone finds them: document order, each one's own
      # references right after it.
      def symbols(algorithm)
        sprite = @configuration.sprite
        needed = []
        visit = lambda do |refs|
          refs.each do |id|
            next if needed.include?(id) || !sprite.key?(id)

            needed << id
            visit.call(sprite.references(id))
          end
        end
        visit.call(algorithm.descendants.flat_map { Svg.references(_1.attributes) })
        needed.map { Svg::Raw.new(sprite.markup(_1)) }
      end
    end
  end
end

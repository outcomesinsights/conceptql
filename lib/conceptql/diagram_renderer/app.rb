# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # The in-app SVG of a diagram: the <svg class="vis"> element that
    # frontend/lib/conceptql-diagram/src/renderer.js builds (its constructor,
    # then update() at duration 0), for a page to show and script. The root
    # svg, the injected <style>, the hidden copy of the icon sprite, the
    # gradients and the Drawing with hooks (data-node-id, data-insert-before,
    # data-diagram-key; see Drawing).
    #
    # Fit-to-view stays in the browser: renderer.js measures the drawing with
    # getBBox and sets the .vis-algorithm transform, so this SVG has none.
    #
    #   ConceptQL::DiagramRenderer::App.new(configuration).render(tree, lock_nodes: true) # => SVG text
    class App
      # XMLSerializer leaves out a namespace declaration that the element
      # already inherits. The sprite <div> is in the SVG namespace (d3 appends
      # it to the svg), so the browser's copy of the sprite has no
      # xmlns="http://www.w3.org/2000/svg".
      INHERITED_XMLNS = /\s+xmlns\s*=\s*(?:"#{Regexp.escape(Static::SVG_NS)}"|'#{Regexp.escape(Static::SVG_NS)}')/
      START_TAG = /<[^\s!?\/>][^>]*>/

      def initialize(configuration)
        @configuration = configuration
      end

      # tree is a diagram tree whose nodes have ids, isSelected and
      # isAttachable (what Ember passes to the renderer, or DiagramData.from's
      # output). It is drawn as it is. styles and icons are the renderer's
      # options of those names: the CSS and the sprite markup (default: the
      # configuration's).
      def render(tree, styles: @configuration.styles, icons: @configuration.icons, lock_nodes: false, summary: false,
        show_counts: false, show_options: false, css_transforms: false)
        drawing = Drawing.new(tree, show_counts:, show_options:, hooks: true, lock_nodes:, css_transforms:)
        Svg.element("svg", {
          "xmlns" => Static::SVG_NS,
          "xmlns:xlink" => Static::XLINK_NS,
          "class" => lock_nodes ? "vis is-new" : "vis",
          "height" => "100%",
          "width" => "100%",
          "viewBox" => summary ? "0 0 800 500" : nil
        }, [
          Svg.element("style", {}, styles.nil? ? [] : [ styles ]),
          Svg.element("div", { "style" => "display: none;" }, icons.nil? || icons.empty? ? [] : [ Svg::Raw.new(serialized(icons)) ]),
          Svg.element("defs", {}, drawing.gradients),
          drawing.algorithm
        ]).to_s
      end

      private

      # The sprite markup as the browser serializes the <div> after its
      # innerHTML is set. The markup must otherwise be in serialized form, as
      # the sprite in frontend/index.html is.
      def serialized(icons) = icons.gsub(START_TAG) { _1.gsub(INHERITED_XMLNS, "") }
    end
  end
end

# frozen_string_literal: true

require_relative "paths"

module ConceptQL
  # The ConceptQL diagram renderer: a diagram tree (ConceptQL::Diagram.render)
  # to a standalone static SVG (render_static), a PNG (png) or the in-app SVG
  # (render_app). See docs/diagram_renderer.md. It uses the Ruby standard
  # library and the resvg program only. lib/conceptql.rb autoloads it, so
  # `require "conceptql"` loads none of it, and a plain Ruby process can load
  # it alone:
  #
  #   ruby -Ilib -e 'require "conceptql/diagram_renderer"; ConceptQL::DiagramRenderer::Geometry'
  #
  # It is a port of the JavaScript renderer of the Jigsaw diagram editor
  # (frontend/lib/conceptql-diagram in the jigsaw-diagram-editor repository).
  # The comments name the JavaScript files by their paths in that repository.
  module DiagramRenderer
    class << self
      # The asset configuration (Configuration) that render_static and png use.
      def configuration = @configuration ||= Configuration.new

      # Replace the configuration with a new one that the block sets up.
      def configure
        config = Configuration.new
        yield config
        @configuration = config
      end

      # The standalone static SVG of a diagram tree (DiagramData.from takes the
      # input), as text. show_counts labels each stream with its child's
      # counts; show_options lists each node's options under its values.
      def render_static(input, show_counts: false, show_options: false)
        Static.new(configuration).render(input, show_counts:, show_options:)
      end

      # The static SVG rasterized by resvg, as PNG bytes, at the SVG's width and
      # height.
      def png(input, show_counts: false, show_options: false)
        configuration.resvg.png(render_static(input, show_counts:, show_options:))
      end

      # The in-app SVG (App) of a diagram tree whose nodes have ids, as text:
      # the svg.vis element of renderer.js, with click hooks and stable keys.
      # Options: styles, icons, lock_nodes, summary, show_counts, show_options
      # and css_transforms (see App#render and docs/diagram_renderer.md).
      def render_app(tree, **options)
        App.new(configuration).render(tree, **options)
      end
    end
  end
end

require_relative "diagram_renderer/js_format"
require_relative "diagram_renderer/tree_layout"
require_relative "diagram_renderer/geometry"
require_relative "diagram_renderer/resvg"
require_relative "diagram_renderer/input_error"
require_relative "diagram_renderer/diagram_data"
require_relative "diagram_renderer/svg"
require_relative "diagram_renderer/sprite"
require_relative "diagram_renderer/configuration"
require_relative "diagram_renderer/drawing"
require_relative "diagram_renderer/static"
require_relative "diagram_renderer/app"

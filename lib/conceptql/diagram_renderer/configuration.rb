# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # Where the renderer's assets are. Each path defaults to the copy that the
    # gem ships under assets/diagram/ (ASSETS), so a host needs no configure
    # call. A host that has its own copy of an asset sets that path:
    #
    #   ConceptQL::DiagramRenderer.configure do |config|
    #     config.styles_path = "my_diagram.css"
    #   end
    #
    # - sprite_path: a file that holds the operator icon <symbol>s (Sprite):
    #   assets/diagram/operators.svg.
    # - styles_path: the diagram CSS: assets/diagram/diagram.css.
    # - webfonts_dir: the WEBFONTS woff2 files, embedded in the SVG's <style>:
    #   assets/diagram/fonts.
    # - resvg_fonts_dir: the Resvg::FONT_FILES TTF files for resvg:
    #   assets/diagram/fonts.
    # - resvg_program: the resvg executable, "resvg" (on PATH) by default.
    #
    # The files are read once, when first needed.
    class Configuration
      # The gem's asset directory.
      ASSETS = ConceptQL.root.join("assets", "diagram")

      # The Roboto webfonts and their font-style (loadAssets in
      # cli/src/render-static.js).
      WEBFONTS = [ [ "Roboto-Normal-Latin.woff2", "normal" ], [ "Roboto-Italic-Latin.woff2", "italic" ] ].freeze

      # The rule for the root svg after the diagram CSS. animation: none is
      # required: the diagram CSS fades .vis in after a delay, and an SVG shown
      # as an image runs its CSS animations, so anything that snapshots the
      # file early (thumbnailers, PDF converters) gets a blank.
      ROOT_RULE = %(svg.vis { font: normal 15px/1.5 "Roboto", sans-serif; animation: none; cursor: default; }\n)

      # An asset path is not set.
      class Missing < StandardError; end

      attr_accessor :sprite_path, :styles_path, :webfonts_dir, :resvg_fonts_dir, :resvg_program

      def initialize
        @sprite_path = ASSETS.join("operators.svg").to_s
        @styles_path = ASSETS.join("diagram.css").to_s
        @webfonts_dir = ASSETS.join("fonts").to_s
        @resvg_fonts_dir = ASSETS.join("fonts").to_s
        @resvg_program = "resvg"
      end

      # The sprite block in an HTML page (loadAssets in cli/src/render-static.js).
      OPERATORS = %r{<div class="operators"[^>]*>(.*?)</div>\s*(?:<|\z)}m

      def sprite = @sprite ||= Sprite.new(sprite_markup)

      def styles = @styles ||= File.read(path(:styles_path))

      # The icon markup that the in-app SVG copies (App): the content of the
      # <div class="operators"> block when the sprite file has one, else the
      # whole file.
      def icons = @icons ||= sprite_markup[OPERATORS, 1] || sprite_markup

      # The text of the standalone SVG's <style>: the embedded Roboto faces, the
      # diagram CSS and ROOT_RULE (standaloneStyleText in
      # cli/src/render-static.js).
      def standalone_style_text
        @standalone_style_text ||= "#{font_faces}\n#{styles}\n#{ROOT_RULE}"
      end

      def resvg = Resvg.new(fonts_dir: path(:resvg_fonts_dir), program: resvg_program)

      private

      def sprite_markup = @sprite_markup ||= File.read(path(:sprite_path))

      def font_faces
        WEBFONTS.map do |file, style|
          data = [ File.binread(File.join(path(:webfonts_dir), file)) ].pack("m0")
          %(@font-face { font-family: "Roboto"; font-style: #{style}; font-weight: 100 900; src: url(data:font/woff2;base64,#{data}) format("woff2"); })
        end.join("\n")
      end

      def path(name)
        public_send(name)&.to_s or raise Missing, "ConceptQL::DiagramRenderer: #{name} is not set (see ConceptQL::DiagramRenderer.configure)"
      end
    end
  end
end

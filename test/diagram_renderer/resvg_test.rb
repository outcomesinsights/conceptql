# frozen_string_literal: true

require "digest"
require_relative "helper"

# Runs the resvg program that mise.toml pins.
describe ConceptQL::DiagramRenderer::Resvg do
  fonts_dir = ConceptQL::DiagramRenderer::Configuration.new.resvg_fonts_dir
  statements = DiagramRendererTest::STATEMENTS
  references = Dir.glob("**/reference/static.svg", base: statements).sort

  let(:resvg) { ConceptQL::DiagramRenderer::Resvg.new(fonts_dir:) }

  def svg(body, view_box: "0 0 100 100")
    %(<svg xmlns="http://www.w3.org/2000/svg" data-note="a>b" viewBox="#{view_box}" width="100" height="100">#{body}</svg>)
  end

  def view_box_of(svg) = svg[/\A<svg\b[^>]* viewBox="([^"]+)"/, 1]

  # The text of the static SVG's <style> (standaloneStyleText() in
  # cli/src/render-static.js), from the gem's assets. The committed references
  # hold only its digest (SvgComparison.normalize), and the CSS sets the font,
  # so the box needs the whole text.
  def static_style_text
    DiagramRendererTest.configure!
    ConceptQL::DiagramRenderer.configuration.standalone_style_text
  end

  # The SVG that fitToContent (cli/src/render-static.js) measures: the
  # reference with its <style> text back, without the background rect, and
  # with the measuring viewBox and size.
  def measure_input(reference, style)
    digest = reference[%r{<style>sha256:(\h{64})</style>}, 1]
    _(digest).must_equal(Digest::SHA256.hexdigest(style), "the reference's <style> is not today's standaloneStyleText()")

    escaped = style.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    background = %r{<rect x="[^"]*" y="[^"]*" width="[^"]*" height="[^"]*" fill="#f4f2f3"/>}
    _(reference.scan(background).size).must_equal(1)
    reference
      .sub(%r{<style>sha256:\h{64}</style>}) { "<style>#{escaped}</style>" }
      .sub(background, "")
      .sub(/\A(<svg\b[^>]*) viewBox="[^"]+" width="[^"]+" height="[^"]+"/) { %(#{Regexp.last_match(1)} viewBox="-5000 -5000 10000 10000" width="10000" height="10000") }
  end

  it "runs the pinned release" do
    _(resvg.version).must_equal(ConceptQL::DiagramRenderer::Resvg::VERSION)
  end

  describe "#bbox" do
    it "gives the box of the drawing in user units" do
      _(resvg.bbox(svg('<rect x="10" y="20" width="30" height="40"/>'))).must_equal([ 10.0, 20.0, 30.0, 40.0 ])
    end

    it "does not depend on the viewBox" do
      wide = svg('<rect x="10" y="20" width="30" height="40"/>', view_box: "-5000 -5000 10000 10000")
      _(resvg.bbox(wide)).must_equal([ 10.0, 20.0, 30.0, 40.0 ])
    end

    # Half the stroke width on each side, as resvg-js getBBox() gives it.
    it "includes the stroke" do
      stroked = svg('<rect x="10" y="20" width="30" height="40" stroke="black" stroke-width="2"/>')
      _(resvg.bbox(stroked)).must_equal([ 9.0, 19.0, 32.0, 42.0 ])
    end

    it "raises Resvg::Error for an empty drawing" do
      error = _ { resvg.bbox(svg("")) }.must_raise(ConceptQL::DiagramRenderer::Resvg::Error)
      _(error.message).must_match(/no valid ID/)
    end

    it "finds 70 reference static SVGs" do
      _(references.size).must_equal(70)
    end

    # The acceptance rule of bead jigsaw-diagram-editor-t5dq.2: the padded
    # floor/ceil box (fitToContent) equals each reference's viewBox.
    references.each do |file|
      it "gives the viewBox of #{File.dirname(file, 2)}" do
        reference = File.read(File.join(statements, file))
        x, y, width, height = resvg.bbox(measure_input(reference, static_style_text))
        padded = [ (x - 24).floor, (y - 24).floor, (width + 48).ceil, (height + 48).ceil ]
        _(padded.join(" ")).must_equal(view_box_of(reference))
      end
    end
  end

  describe "#png" do
    it "draws a reference static SVG at the size of its viewBox" do
      reference = File.read(File.join(statements, "icd9_412/reference/static.svg"))
      png = resvg.png(reference)
      _(png.byteslice(0, 8)).must_equal("\x89PNG\r\n\x1A\n".b)
      _(png.byteslice(12, 4)).must_equal("IHDR")
      _, _, width, height = view_box_of(reference).split.map(&:to_i)
      _(png.byteslice(16, 8).unpack("NN")).must_equal([ width, height ])
    end
  end

  describe "errors" do
    it "names a missing program" do
      missing = ConceptQL::DiagramRenderer::Resvg.new(fonts_dir:, program: "resvg-not-installed")
      error = _ { missing.png(svg("")) }.must_raise(ConceptQL::DiagramRenderer::Resvg::Error)
      _(error.message).must_match(/resvg-not-installed/)
    end

    it "gives the command, the exit status and stderr of a failed run" do
      error = _ { resvg.png("<svg") }.must_raise(ConceptQL::DiagramRenderer::Resvg::Error)
      _(error.command.first).must_equal("resvg")
      _(error.status).must_equal(1)
      _(error.stderr).must_include("root node")
      _(error.message).must_include("exit status 1")
      _(error.message).must_include("stderr: Error:")
    end
  end
end

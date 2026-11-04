# frozen_string_literal: true

require_relative "helper"

# The asset paths default to the gem's copies under assets/diagram/, so a host
# needs no configure call. They replace the editor's
# spec/support/conceptql_diagram_assets.rb.
describe ConceptQL::DiagramRenderer::Configuration do
  let(:config) { ConceptQL::DiagramRenderer::Configuration.new }

  it "finds every default asset under the gem's assets/diagram" do
    assets = ConceptQL.root.join("assets", "diagram").to_s
    paths = [ config.sprite_path, config.styles_path, config.webfonts_dir, config.resvg_fonts_dir ]

    paths.each { |path| _(path).must_include(assets) }
    assert File.file?(config.sprite_path), config.sprite_path
    assert File.file?(config.styles_path), config.styles_path
    ConceptQL::DiagramRenderer::Configuration::WEBFONTS.each do |file, _style|
      assert File.file?(File.join(config.webfonts_dir, file)), file
    end
    ConceptQL::DiagramRenderer::Resvg::FONT_FILES.each do |file|
      assert File.file?(File.join(config.resvg_fonts_dir, file)), file
    end
    _(config.resvg_program).must_equal("resvg")
  end

  it "keeps a path that configure sets, and the defaults for the others" do
    ConceptQL::DiagramRenderer.configure { |c| c.styles_path = "/elsewhere/diagram.css" }

    _(ConceptQL::DiagramRenderer.configuration.styles_path).must_equal("/elsewhere/diagram.css")
    _(ConceptQL::DiagramRenderer.configuration.sprite_path).must_equal(config.sprite_path)
  ensure
    DiagramRendererTest.configure!
  end

  it "raises Missing for a path that is set to nil" do
    ConceptQL::DiagramRenderer.configure { |c| c.styles_path = nil }

    error = _ { ConceptQL::DiagramRenderer.configuration.styles }.must_raise(ConceptQL::DiagramRenderer::Configuration::Missing)
    _(error.message).must_include("styles_path is not set")
  ensure
    DiagramRendererTest.configure!
  end
end

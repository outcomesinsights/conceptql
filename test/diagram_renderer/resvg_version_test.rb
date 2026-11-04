# frozen_string_literal: true

require "tmpdir"
require_relative "helper"

# The first render_static or png call in a process runs `resvg --version`.
# Another version than Resvg::VERSION gets one warning on stderr, and the
# renderer draws anyway.
describe "ConceptQL::DiagramRenderer resvg version check" do
  tree_file = File.join(DiagramRendererTest::STATEMENTS, "icd9_412/render_tree.json")

  def renderer = ConceptQL::DiagramRenderer

  # Forget an earlier check, so that the next call checks again.
  def reset_check = renderer.instance_variable_set(:@resvg_version_checked, nil)

  # A program that reports version as its version and passes every other
  # command to the resvg on PATH.
  def with_fake_resvg(version)
    Dir.mktmpdir("conceptql-fake-resvg") do |dir|
      program = File.join(dir, "resvg")
      File.write(program, <<~SH)
        #!/bin/sh
        if [ "$1" = "--version" ]; then echo #{version}; exit 0; fi
        exec resvg "$@"
      SH
      File.chmod(0o755, program)
      ConceptQL::DiagramRenderer.configure { |c| c.resvg_program = program }
      yield
    end
  end

  let(:tree) { JSON.parse(File.read(tree_file)) }

  before { reset_check }

  after do
    reset_check
    DiagramRendererTest.configure!
  end

  it "warns once over two renders by another version, and draws" do
    svg = png = nil
    _, stderr = capture_io do
      with_fake_resvg("0.34.0") do
        svg = renderer.render_static(tree)
        png = renderer.png(tree)
      end
    end

    _(stderr.lines).must_equal([ "ConceptQL::DiagramRenderer: resvg 0.34.0 is not the required version 0.33.0. The diagrams can be wrong.\n" ])
    _(Nokogiri::XML(svg).root["viewBox"]).wont_be_nil
    _(png.byteslice(0, 8)).must_equal("\x89PNG\r\n\x1A\n".b)
  end

  it "does not warn for the required version" do
    DiagramRendererTest.configure!
    _, stderr = capture_io do
      renderer.render_static(tree)
      renderer.png(tree)
    end

    _(stderr).must_be_empty
  end
end

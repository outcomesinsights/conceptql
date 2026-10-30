# frozen_string_literal: true

require "tmpdir"
require_relative "../../helper"
require_relative "../../../script/spec/grapher"

# `just spec` draws each diagram of doc/spec/ into a temporary file in the
# same directory and renames it over the tracked PNG only after the renderer
# succeeds. An interrupted or failed run leaves the old PNG whole (bead
# conceptql-4bd). The renderer is a stand-in for `dot`, so no graphviz is
# needed except for the last test.
describe "SpecGrapher.draw" do
  # A renderer that reads the dot source and writes +bytes+ to the file
  # named after -o, then exits with +status+.
  def renderer(bytes, status: 0)
    # draw appends "-o", <file>, so they arrive as $3 and $4.
    [ "sh", "-c", "cat >/dev/null; printf '%s' \"$1\" > \"$4\"; exit $2", "sh", bytes, status.to_s ]
  end

  def draw_into(dir, command)
    png = File.join(dir, "abc.png")
    File.write(png, "old")
    SpecGrapher.draw("digraph G {}\n", png, command: command)
    png
  end

  it "replaces the diagram with what the renderer wrote" do
    Dir.mktmpdir do |dir|
      png = draw_into(dir, renderer("new"))

      _(File.read(png)).must_equal "new"
      _(Dir.children(dir)).must_equal [ "abc.png" ]
    end
  end

  it "keeps the old diagram whole when the renderer fails part-way" do
    Dir.mktmpdir do |dir|
      png = File.join(dir, "abc.png")

      _ { draw_into(dir, renderer("trunc", status: 1)) }.must_raise RuntimeError
      _(File.read(png)).must_equal "old"
      _(Dir.children(dir)).must_equal [ "abc.png" ]
    end
  end

  it "draws a PNG with graphviz dot" do
    skip "graphviz dot is not on PATH" unless system("command -v dot >/dev/null 2>&1")

    Dir.mktmpdir do |dir|
      png = File.join(dir, "abc.png")
      SpecGrapher.draw("digraph G { a -> b }\n", png)

      _(File.binread(png, 8)).must_equal "\x89PNG\r\n\x1A\n".b
      _(Dir.children(dir)).must_equal [ "abc.png" ]
    end
  end
end

# frozen_string_literal: true

require "tmpdir"
require_relative "../../helper"
require_relative "../../../docs/spec/build/spec_build"

# `just spec-check` (a step of `just release-check`) fails on the images that
# SpecBuild.outdated returns. No database is needed.
describe "SpecBuild.outdated" do
  tree = { statements: [ { name: "ICD-9 CM", counts: { condition_occurrence: { n: 1 } }, children: [] } ] }
  other = { statements: [ { name: "ICD-9 CM", counts: { condition_occurrence: { n: 2 } }, children: [] } ] }

  def with_images(*names)
    Dir.mktmpdir do |dir|
      names.each { |name| File.write(File.join(dir, name), "<svg/>") }
      yield dir
    end
  end

  it "accepts an image whose manifest hash is the sha256 of its tree's canonical JSON" do
    _(SpecBuild.sha(tree)).must_equal Digest::SHA256.hexdigest(JSON.generate(SpecBuild.canonical(tree)))
    with_images("a.svg") do |dir|
      _(SpecBuild.outdated({ "a.svg" => tree }, "a.svg\t#{SpecBuild.sha(tree)}\n", dir)).must_equal({})
    end
  end

  it "names an image whose tree changed as stale" do
    with_images("a.svg", "b.svg") do |dir|
      manifest = "a.svg\t#{SpecBuild.sha(tree)}\nb.svg\t#{SpecBuild.sha(tree)}\n"
      _(SpecBuild.outdated({ "a.svg" => tree, "b.svg" => other }, manifest, dir)).must_equal({ "b.svg" => "stale" })
    end
  end

  it "names an image that the manifest does not list as stale" do
    with_images("a.svg") do |dir|
      _(SpecBuild.outdated({ "a.svg" => tree }, "", dir)).must_equal({ "a.svg" => "stale" })
    end
  end

  it "names an image file that does not exist as MISSING" do
    with_images do |dir|
      _(SpecBuild.outdated({ "a.svg" => tree }, "a.svg\t#{SpecBuild.sha(tree)}\n", dir)).must_equal({ "a.svg" => "MISSING" })
    end
  end

  # An image that README.cql.md places by hand (images/any_overlap.png) is not an SVG.
  it "names an SVG file that no tree names as unused, and ignores other files" do
    with_images("a.svg", "b.svg", "c.png") do |dir|
      _(SpecBuild.outdated({ "a.svg" => tree }, "a.svg\t#{SpecBuild.sha(tree)}\n", dir)).must_equal({ "b.svg" => "unused" })
    end
  end
end

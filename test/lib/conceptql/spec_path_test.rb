# frozen_string_literal: true

require_relative "../../helper"

# The gem ships the specification so that applications can serve it
# (bead conceptql-8x4). No live database is needed.
describe "ConceptQL.spec_path" do
  it "points to docs/spec/README.md under the gem root" do
    _(ConceptQL.spec_path).must_equal ConceptQL.root / "docs" / "spec" / "README.md"
    _(ConceptQL.spec_path).must_be :file?
  end

  it "is in the files the gemspec ships, without the spec's images" do
    gemspec = Gem::Specification.load(ConceptQL.root.join("conceptql.gemspec").to_s)

    _(gemspec.files).must_include "docs/spec/README.md"
    _(gemspec.files.grep(%r{\Adocs?/})).must_equal [ "docs/spec/README.md" ]
  end
end

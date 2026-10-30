# frozen_string_literal: true

require_relative "../../helper"

# The gem ships the specification so that applications can serve it
# (bead conceptql-8x4). No live database is needed.
describe "ConceptQL.spec_path" do
  it "points to doc/spec.md under the gem root" do
    _(ConceptQL.spec_path).must_equal ConceptQL.root / "doc" / "spec.md"
    _(ConceptQL.spec_path).must_be :file?
  end

  it "is in the files the gemspec ships" do
    gemspec = Gem::Specification.load(ConceptQL.root.join("conceptql.gemspec").to_s)

    _(gemspec.files).must_include "doc/spec.md"
    _(gemspec.files.grep(%r{\Adoc/})).must_equal [ "doc/spec.md" ]
  end
end

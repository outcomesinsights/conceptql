# frozen_string_literal: true

require_relative "../../helper"

# The gem ships the specification so that applications can serve it
# (bead conceptql-8x4). No live database is needed.
describe "ConceptQL.spec_path" do
  it "points to docs/spec/README.md under the gem root" do
    _(ConceptQL.spec_path).must_equal ConceptQL.root / "docs" / "spec" / "README.md"
    _(ConceptQL.spec_path).must_be :file?
  end

  it "is in the files the gemspec ships, with the example files and without the spec's images" do
    gemspec = Gem::Specification.load(ConceptQL.root.join("conceptql.gemspec").to_s)
    examples = ConceptQL.spec_examples_path.glob("*.json").map { |path| path.relative_path_from(ConceptQL.root).to_s }

    _(gemspec.files).must_include "docs/spec/README.md"
    _(gemspec.files.grep(%r{\Adocs?/}).sort).must_equal [ "docs/spec/README.md", *examples ].sort
  end
end

# One example file for each published spec_id (bead conceptql-jwsv.11), which
# applications read to show an operator's help. `just spec` writes them.
describe "ConceptQL.spec_examples_path" do
  files = ConceptQL.spec_examples_path.glob("*.json").sort

  it "points to docs/spec/examples under the gem root and holds the example files" do
    _(ConceptQL.spec_examples_path).must_equal ConceptQL.root / "docs" / "spec" / "examples"
    _(ConceptQL.spec_examples_path).must_be :directory?
    _(files.size).must_be :>, 30
  end

  files.each do |path|
    it "gives each example of #{path.basename} a title, statement, help, columns, rows and a diagram tree" do
      doc = JSON.parse(path.read)

      _(doc["spec_id"]).must_equal path.basename(".json").to_s
      _(doc["examples"]).wont_be_empty
      doc["examples"].each do |example|
        _(example.keys).must_equal %w[title statement help columns rows tree]
        _([ true, false ]).must_include example["help"]
        _(example["rows"].size).must_be :<=, 10
        example["rows"].each { |row| _(row.size).must_equal example["columns"].size }
        _(example["tree"]["format"]).must_equal "conceptql-diagram/v1"
      end
    end
  end
end

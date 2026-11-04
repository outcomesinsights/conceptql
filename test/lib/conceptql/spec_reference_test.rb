# frozen_string_literal: true

require_relative "../../helper"
require_relative "../../../docs/spec/build/spec_build"

# The spec build writes each published spec_id's reference section and
# Appendix E from ConceptQL.metadata (SpecBuild::Reference, bead
# conceptql-jwsv.10). Database.new(nil, data_model: :gdm) decides which
# operators are published. No database is needed.
published = ConceptQL.metadata(ConceptQL::Database.new(nil, data_model: :gdm))

describe "the reference documentation of each published spec_id" do
  sections = published[:operators].values.group_by { |operator| operator[:spec_id] }

  it "covers the vocabulary operators and the other operators" do
    _(sections.keys).must_include "vocabulary-operator"
    _(sections.keys).must_include "union-operator"
  end

  sections.each do |spec_id, operators|
    it "gives #{spec_id} a desc, a returns text, a text for each option and argument, and an example" do
      operators.each do |operator|
        name = operator[:name]
        _(operator[:desc].to_s.strip).wont_be_empty "#{name} has no desc"
        _(operator[:returns].to_s.strip).wont_be_empty "#{name} has no returns text"
        (operator[:options].to_a + operator[:arguments]).each do |param, opt|
          _(opt[:meaning].to_s.strip).wont_be_empty "#{name} #{param} has no meaning: text"
        end
      end
      _(operators.flat_map { |operator| operator[:examples] }).wont_be_empty "#{spec_id} has no example"
    end
  end
end

describe "SpecBuild::Reference" do
  def operator(name, spec_id, **overrides)
    { name: name, spec_id: spec_id, desc: "Desc of #{name}.", returns: "Returns of #{name}.",
      min_upstreams: 1, max_upstreams: 1, categories: [ [ "Combine Streams" ] ], arguments: [],
      options: { label: { type: :string, meaning: "The label text." } }, examples: [] }.merge(overrides)
  end

  def metadata(*operators)
    { categories: ConceptQL.categories, operators: operators.to_h { |op| [ op[:name], op ] } }
  end

  let(:joiner) do
    operator("joiner", "joiner-operator",
             min_upstreams: 0, max_upstreams: 0, categories: [ [ "Filter by Comparing" ] ],
             arguments: [ [ :codes, { type: :codelist, meaning: "The codes." } ] ],
             options: { label: { type: :string, meaning: "The label text." },
                        left: { type: :upstream, required: true, meaning: "The left stream." },
                        right: { type: :upstream, required: true, meaning: "The right stream." },
                        within: { type: :string, instructions: "Type 30d", meaning: "The window." },
                        pick: { type: :string, options: [ "A", "B" ], meaning: "The pick." } },
             examples: [ { title: "No rows", statement: [ "joiner", "1" ], help: false },
                         { title: "Rows", statement: [ "joiner", { left: [ "icd9", "412" ] } ], help: true } ])
  end
  let(:merger) { operator("merger", "merger-operator", min_upstreams: 1, max_upstreams: 99) }
  let(:reference) { SpecBuild::Reference.new(metadata(joiner, merger)) }

  let(:source) do
    <<~MD.lines
      # Spec

      ### `Joiner` Operator

      <!-- conceptql-spec: operator joiner-operator -->

      More about joiner.

      ## Merger Operator

      <!-- conceptql-spec: operator merger-operator -->

      ## Label

      <!-- conceptql-spec: label-option -->

      ## Appendix E

      <!-- conceptql-spec: quick-reference -->
    MD
  end

  def expanded(lines = source)
    reference.expand(lines).map(&:text).join
  end

  def error(lines)
    _ { reference.expand(lines) }.must_raise(RuntimeError).message
  end

  describe "a reference section" do
    let(:section) { reference.section("joiner-operator") }

    it "lists the desc, the operands, the arguments, the options, returns and the examples in that order" do
      parts = [ "Desc of joiner.", "- **Operands:**", "- **Arguments:**", "- **Options:**", "- **Returns:** Returns of joiner.",
                "# Rows", "# No rows" ]
      positions = parts.map { |part| section.index(part) }
      _(positions).wont_include nil
      _(positions).must_equal positions.sort
    end

    it "shows left and right as operands and leaves out the upstream line of an operator without upstreams" do
      _(section).must_include "  - `left` (required): The left stream.\n  - `right` (required): The right stream."
      _(section).wont_include "Upstream"
    end

    it "gives each option its type, whether it is required, its values and its meaning, but not its instructions" do
      _(section).must_include "  - `within` (string): The window."
      _(section).must_include "  - `pick` (string, one of `A`, `B`): The pick."
      _(section).must_include "  - `codes` (codelist): The codes."
      _(section).wont_include "Type 30d"
    end

    it "does not list the label option" do
      _(section).wont_include "label"
    end

    it "writes each example as a ConceptQL block, the examples shown in help first" do
      _(section).must_include "```ConceptQL\n# Rows\n[\"joiner\",{\"left\":[\"icd9\",\"412\"]}]\n```\n\n```ConceptQL\n# No rows\n[\"joiner\",\"1\"]\n```"
    end

    it "says how many upstream operators an operator takes" do
      _(reference.section("merger-operator")).must_include "- **Upstream:** one or more operators.\n- **Returns:**"
    end

    it "raises for upstream counts that it has no text for" do
      odd = SpecBuild::Reference.new(metadata(operator("odd", "odd-operator", min_upstreams: 2, max_upstreams: 3)))
      _ { odd.section("odd-operator") }.must_raise KeyError
    end
  end

  describe "the directives" do
    it "replace each directive with its markdown and keep the other lines" do
      text = expanded
      _(text).must_include "### `Joiner` Operator\n\nDesc of joiner.\n"
      _(text).must_include "More about joiner.\n"
      _(text).must_include "## Label\n\nThe label text.\n"
      _(text).wont_include "<!--"
    end

    it "name the place in README.cql.md of each generated line" do
      lines = reference.expand(source)
      _(lines.find { |line| line.text == "Desc of joiner.\n" }.origin).must_equal "README.cql.md:5 (<!-- conceptql-spec: operator joiner-operator -->)"
      _(lines.find { |line| line.text == "More about joiner.\n" }.origin).must_equal "README.cql.md:7"
    end

    it "fail when a published spec_id has no section" do
      _(error(source.reject { |line| line.include?("merger-operator") })).must_include "no section for merger-operator"
    end

    it "fail on a spec_id that no published operator has" do
      _(error(source + [ "## Other Operator\n", "<!-- conceptql-spec: operator other-operator -->\n" ])).must_include "no published operator has the spec_id other-operator"
    end

    it "fail on a second section of one spec_id" do
      _(error(source + [ "## Merger Operator\n", "<!-- conceptql-spec: operator merger-operator -->\n" ])).must_include "a second section of merger-operator"
    end

    it "fail when the heading before a directive does not have the spec_id as its anchor" do
      _(error(source.map { |line| line.sub("## Merger Operator", "## Combiner Operator") })).must_include "is not merger-operator"
    end

    it "fail on an unknown directive and on a missing quick-reference" do
      message = error(source.map { |line| line.sub("quick-reference", "quick-guide") })
      _(message).must_include "unknown directive <!-- conceptql-spec: quick-guide -->"
      _(message).must_include "0 quick-reference directives, not 1"
    end
  end

  describe "Appendix E" do
    it "has one row per spec_id, ordered by category, with the desc" do
      _(expanded).must_include <<~MD
        | Operator | Jigsaw category | What it does |
        | --- | --- | --- |
        | [`merger`](#merger-operator) | Combine Streams | Desc of merger. |
        | [`joiner`](#joiner-operator) | Filter by Comparing | Desc of joiner. |
      MD
    end
  end

  describe "the vocabulary operators" do
    let(:vocabularies) do
      SpecBuild::Reference.new(metadata(operator("icd9cm", "vocabulary-operator", desc: "Selects ICD9CM."),
                                        operator("cpt4", "vocabulary-operator", desc: "Selects CPT4.")))
    end

    it "share one section with the desc of the Vocabulary class" do
      _(vocabularies.desc("vocabulary-operator")).must_equal ConceptQL::Operators::Vocabulary.desc
    end

    it "link Appendix E with the heading of their section" do
      table = vocabularies.quick_reference("vocabulary-operator" => "`Vocabulary` Operator")
      _(table).must_include "| [`Vocabulary` Operator](#vocabulary-operator) | Combine Streams | #{ConceptQL::Operators::Vocabulary.desc} |"
    end

    it "is the only section whose operators can have different descs" do
      other = SpecBuild::Reference.new(metadata(operator("a", "a-operator", desc: "A."), operator("b", "a-operator", desc: "B.")))
      _ { other.desc("a-operator") }.must_raise RuntimeError
    end
  end

  # bead conceptql-rx42
  describe "the table of the vocabulary operators" do
    def vocabulary(name, long_name, domains = [ "condition_occurrence" ], **overrides)
      operator(name, "vocabulary-operator", long_name: long_name, predominant_domains: domains, **overrides)
    end

    let(:vocabularies) do
      SpecBuild::Reference.new(metadata(vocabulary("icd9cm", "ICD-9-CM | NCHS"),
                                        vocabulary("cpt_or_hcpcs", "CPT4 and HCPCS", %w[procedure_occurrence observation]),
                                        vocabulary("drg", "DRG", deprecated: true),
                                        joiner))
    end

    let(:vocabulary_source) do
      source + [ "## `Vocabulary` Operator\n", "<!-- conceptql-spec: operator vocabulary-operator -->\n",
                 "### All Vocabulary Operators\n", "<!-- conceptql-spec: vocabulary-operators -->\n" ]
    end

    def expand(reference, lines)
      reference.expand(lines).map(&:text).join
    end

    it "has one row per vocabulary operator, ordered by name, with its long name and its domains" do
      _(vocabularies.vocabulary_operators).must_equal <<~MD
        | Operator | Vocabulary | Domain |
        | --- | --- | --- |
        | `cpt_or_hcpcs` | CPT4 and HCPCS | procedure_occurrence, observation |
        | `drg` (deprecated) | DRG | condition_occurrence |
        | `icd9cm` | ICD-9-CM \\| NCHS | condition_occurrence |
      MD
    end

    it "fails for a vocabulary operator without a long name or a domain" do
      blank = SpecBuild::Reference.new(metadata(vocabulary("read", "")))
      _(_ { blank.vocabulary_operators }.must_raise(RuntimeError).message).must_include "read has no long_name"
      none = SpecBuild::Reference.new(metadata(vocabulary("read", "Read", [])))
      _(_ { none.vocabulary_operators }.must_raise(RuntimeError).message).must_include "read has no domain"
    end

    it "replaces its directive" do
      text = expand(vocabularies, vocabulary_source.reject { |line| line.include?("merger-operator") })
      _(text).must_include "### All Vocabulary Operators\n#{vocabularies.vocabulary_operators}"
    end

    it "fails when its directive is missing or repeated" do
      lines = vocabulary_source.reject { |line| line.include?("merger-operator") }
      missing = _ { vocabularies.expand(lines.reject { |line| line.include?("vocabulary-operators") }) }.must_raise RuntimeError
      _(missing.message).must_include "0 vocabulary-operators directives, not 1"
      repeated = _ { vocabularies.expand(lines + [ "<!-- conceptql-spec: vocabulary-operators -->\n" ]) }.must_raise RuntimeError
      _(repeated.message).must_include "2 vocabulary-operators directives, not 1"
    end

    it "is not allowed without a published vocabulary operator" do
      _(error(source + [ "<!-- conceptql-spec: vocabulary-operators -->\n" ])).must_include "1 vocabulary-operators directives, not 0"
    end

    it "lists every published vocabulary operator once, with no hidden operator" do
      vocabulary_operators = published[:operators].values.select { |operator| operator[:spec_id] == "vocabulary-operator" }
      rows = SpecBuild::Reference.new(published).vocabulary_operators.lines.drop(2)
      _(rows.map { |row| row[/\A\| `([^`]+)`/, 1] }).must_equal vocabulary_operators.map { |operator| operator[:name] }.sort
      hidden = ConceptQL::Database.new(nil, data_model: :gdm).operators(:gdm).select { |_, klass| klass.hidden? }.keys
      _(hidden).wont_be_empty
      _(rows.join).wont_match(/`(#{hidden.map { |name| Regexp.escape(name) }.join('|')})`/)
    end

    it "marks drg, the deprecated vocabulary operator, and has a long name for read and cpt_or_hcpcs" do
      table = SpecBuild::Reference.new(published).vocabulary_operators
      _(table).must_include "| `drg` (deprecated) | Diagnosis-related group (CMS) | procedure_occurrence |"
      _(table).must_include "| `read` | NHS UK Read Codes Version 2 (HSCIC) | condition_occurrence |"
      _(table).must_include "| `cpt_or_hcpcs` | CPT4, HCPCS and CPT4_HCPCS | procedure_occurrence |"
    end
  end

  # just ci does not run the spec build, so this checks the directives of the
  # real source against the published operators
  it "expands docs/spec/README.cql.md with every published spec_id" do
    real = SpecBuild::Reference.new(published)
    lines = real.expand(File.readlines(SpecBuild::SOURCE)).map(&:text)
    real.spec_ids.each { |spec_id| _(lines.join).must_include real.section(spec_id) }
    _(lines.join).must_include real.vocabulary_operators
    _(File.readlines(SpecBuild::SOURCE).grep(/\A<!-- conceptql-spec: vocabulary-operators -->/).size).must_equal 1
    _(lines.grep(/\A<!-- conceptql-spec:/)).must_be_empty
  end
end

# frozen_string_literal: true

require_relative "../../../helper"

# Each operator class holds its reference documentation: a meaning: text for
# each option and argument, a returns text and examples (seed conceptql-mdo.2,
# bead conceptql-jwsv.6). ConceptQL.metadata serves them. A subclass inherits
# its options with their texts, and can replace the text of one of them. It
# does not inherit returns or the examples, which would show the wrong
# operator. No database: Database.new(nil) decides which operators are
# published.
describe "operator documentation in the metadata" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }
  let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }

  let(:parent) do
    Class.new(ConceptQL::Operators::Operator) do
      desc "Parent operator."
      option :window, type: :string, instructions: "Enter a number of days", meaning: "The parent's window."
      option :other, type: :string, meaning: "The other option."
      argument :codes, type: :codelist, meaning: "The codes to select."
      returns "One result for each parent result."
      example "Parent example", [ "icd9", "412" ]
      example "Parent example kept out of help", [ "icd9", "250.00" ], help: false
    end
  end

  let(:child) do
    Class.new(parent) do
      option_meaning :window, "The child's window."
    end
  end

  describe "an operator class that declares the texts" do
    let(:parent_metadata) { parent.to_metadata("documented") }

    it "serves the meaning of each option and keeps instructions as the typing hint" do
      _(parent_metadata[:options][:window].values_at(:instructions, :meaning)).must_equal [ "Enter a number of days", "The parent's window." ]
      _(parent_metadata[:options][:other][:meaning]).must_equal "The other option."
    end

    it "serves the meaning of each argument" do
      _(parent_metadata[:arguments].to_h[:codes][:meaning]).must_equal "The codes to select."
    end

    it "serves returns" do
      _(parent_metadata[:returns]).must_equal "One result for each parent result."
    end

    it "serves each example as title, statement and help, in order" do
      _(parent_metadata[:examples]).must_equal [
        { title: "Parent example", statement: [ "icd9", "412" ], help: true },
        { title: "Parent example kept out of help", statement: [ "icd9", "250.00" ], help: false }
      ]
    end

    it "appears in ConceptQL.metadata" do
      real = cdb.operators(:gdm)
      klass = parent
      cdb.define_singleton_method(:operators) { |_data_model = :gdm| real.merge("documented" => klass) }

      documented = ConceptQL.metadata(cdb)[:operators].fetch("documented")
      _(documented[:options][:window][:meaning]).must_equal "The parent's window."
      _(documented[:returns]).must_equal "One result for each parent result."
      _(documented[:examples].map { |example| example[:title] }).must_equal [ "Parent example", "Parent example kept out of help" ]
    end
  end

  describe "a subclass" do
    it "replaces the meaning of one inherited option" do
      _(child.to_metadata("child")[:options][:window][:meaning]).must_equal "The child's window."
    end

    it "keeps the other texts of that option and the texts of the other options" do
      options = child.to_metadata("child")[:options]
      _(options[:window][:instructions]).must_equal "Enter a number of days"
      _(options[:other][:meaning]).must_equal "The other option."
      _(options[:label][:meaning]).must_equal ConceptQL::Operators::Operator.to_metadata("operator")[:options][:label][:meaning]
    end

    it "leaves the parent's text alone" do
      child
      _(parent.to_metadata("parent")[:options][:window][:meaning]).must_equal "The parent's window."
    end

    it "does not inherit returns or the examples" do
      # Premise: the parent has both
      _(parent.to_metadata("parent").values_at(:returns, :examples).map(&:present?)).must_equal [ true, true ]

      metadata = child.to_metadata("child")
      _(metadata[:returns]).must_be_nil
      _(metadata[:examples]).must_equal []
    end

    it "cannot replace the meaning of an option that it does not have" do
      _ { Class.new(parent) { option_meaning :no_such_option, "Text" } }.must_raise KeyError
    end
  end

  describe "the base-class texts" do
    it "gives the label option a meaning on every published operator" do
      operators_metadata.each do |name, metadata|
        _(metadata[:options].fetch(:label)[:meaning]).must_match(/\A[A-Z].*\.\z/, name)
      end
    end

    it "gives left and right a meaning on each operator that takes them" do
      with_operands = operators_metadata.select { |_name, metadata| metadata[:options].key?(:left) }
      # Premise: the binary operators are published
      _(with_operands.keys).must_include "before"
      _(with_operands.keys).must_include "person_filter"

      with_operands.each do |name, metadata|
        %i[left right].each do |operand|
          _(metadata[:options].fetch(operand)[:meaning]).must_match(/\A[A-Z].*\.\z/, "#{name} #{operand}")
        end
      end
    end
  end

  describe "one_in_two_out" do
    let(:options) { operators_metadata.fetch("one_in_two_out")[:options] }

    it "has no option key desc:" do
      options.each do |name, opt|
        _(opt.key?(:desc)).must_equal false, name
      end
    end

    it "serves its option texts as meaning" do
      _(options[:inpatient_length_of_stay][:meaning]).must_match(/inpatient stay/)
      _(options[:outpatient_event_to_return][:meaning]).must_match(/passes on/)
    end
  end

  # The vocabulary operators (the generated ones, read and cpt_or_hcpcs)
  # share one reference section, so their returns text and examples are
  # written on ConceptQL::Operators::Vocabulary. Each operator of the section
  # serves the returns text and only the examples whose statement starts with
  # its own name.
  describe "the vocabulary operators" do
    let(:vocabulary) { ConceptQL::Operators::Vocabulary }

    def with_vocabulary_texts(returns, examples)
      saved = %i[@returns @examples].to_h { |ivar| [ ivar, vocabulary.instance_variable_get(ivar) ] }
      vocabulary.instance_variable_set(:@returns, returns)
      vocabulary.instance_variable_set(:@examples, examples)
      yield
    ensure
      saved.each { |ivar, value| vocabulary.instance_variable_set(ivar, value) }
    end

    let(:icd9cm_example) { { title: "Old MI", statement: [ "icd9cm", "412" ], help: true } }
    let(:cpt_or_hcpcs_example) { { title: "Office visit", statement: [ "cpt_or_hcpcs", "99214" ], help: false } }

    it "serves the returns text of Vocabulary on every operator of the section" do
      with_vocabulary_texts("One result for each matching row.", []) do
        section = operators_metadata.select { |_name, metadata| metadata[:spec_id] == "vocabulary-operator" }
        # Premise: the section has a generated vocabulary operator, read and the multiple vocabulary one
        _(section.keys).must_include "icd9cm"
        _(section.keys).must_include "read"
        _(section.keys).must_include "cpt_or_hcpcs"

        section.each do |name, metadata|
          _(metadata[:returns]).must_equal "One result for each matching row.", name
        end
      end
    end

    it "serves each Vocabulary example only on the operator that its statement starts with" do
      with_vocabulary_texts(nil, [ icd9cm_example, cpt_or_hcpcs_example ]) do
        _(operators_metadata.fetch("icd9cm")[:examples]).must_equal [ icd9cm_example ]
        _(operators_metadata.fetch("cpt_or_hcpcs")[:examples]).must_equal [ cpt_or_hcpcs_example ]
        _(operators_metadata.fetch("icd10cm")[:examples]).must_equal []
      end
    end

    it "gives each vocabulary operator a copy of the codes argument of Vocabulary" do
      _(vocabulary.argument_options(:codes)[:type]).must_equal :codelist
      codes_meaning = vocabulary.argument_options(:codes)[:meaning]
      _(codes_meaning).must_match(/\A[A-Z].*\.\z/)
      _(operators_metadata.fetch("icd9cm")[:arguments]).must_equal [ [ :codes, { type: :codelist, meaning: codes_meaning, label: "ICD9CM Codes" } ] ]
    end

    it "lets each declared Vocabulary example appear in ConceptQL.metadata" do
      vocabulary.examples.each do |example|
        name = example[:statement].first.to_s
        _(operators_metadata.fetch(name, {})[:examples]).must_include example, "#{name} is not a published vocabulary operator"
      end
    end
  end
end

# Every example that any operator class declares validates with no errors on
# the database that decides which operators are published.
describe "the declared examples" do
  let(:cdb) { ConceptQL::Database.new(nil, data_model: :gdm) }

  # Each published operator class and the base classes it inherits from,
  # such as Vocabulary and TemporalOperator
  def documented_classes
    cdb.operators(:gdm).values.flat_map do |klass|
      klass.ancestors.grep(Class).take_while { |ancestor| ancestor <= ConceptQL::Operators::Operator }
    end.uniq
  end

  def example_errors(klass)
    klass.examples.filter_map do |example|
      errors = by_operator(cdb.query(example[:statement]).errors)
      "#{klass}: #{example[:title]}: #{errors}" unless errors.empty?
    end
  end

  it "validates each one with no errors" do
    # Premise: the base classes are in the list
    _(documented_classes).must_include ConceptQL::Operators::Vocabulary
    _(documented_classes).must_include ConceptQL::Operators::TemporalOperator

    _(documented_classes.flat_map { |klass| example_errors(klass) }).must_equal []
  end

  it "reports an example that does not validate" do
    bad = Class.new(ConceptQL::Operators::Operator) do
      example "Unknown operator", [ "no_such_operator" ]
      example "Valid", [ "icd9", "412" ]
    end
    _(example_errors(bad).length).must_equal 1
  end
end

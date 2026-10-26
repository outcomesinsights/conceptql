# frozen_string_literal: true

require_relative "../../../helper"

# ConceptQL.metadata marks an option as required when the operator lists it in
# validate_required_options. Every listed option must be marked, not only the
# first, and marking a subclass must leave its parent's metadata alone, because
# a subclass shares the option hashes it inherits (bead conceptql-c97).
# No live database: the mock never answers a query.
describe ConceptQL::Metadatable do
  describe "required options in ConceptQL.metadata" do
    let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
    let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }

    def required_in_metadata(name)
      operators_metadata.fetch(name)[:options].select { |_opt, h| h[:required] }.keys
    end

    def required_in_validations(name)
      cdb.operators(:gdm_wide).fetch(name).validations
        .select { |meth, *| meth == :validate_required_options }
        .flat_map { |_meth, *names| names }
    end

    {
      "provider_filter" => %i[specialties roles],
      "date_range" => %i[start end],
      "before" => %i[left right],
      "filter" => %i[left right],
      "except" => %i[left right],
      "person_filter" => %i[left right]
    }.each do |name, expected|
      it "marks each of #{expected.join(' and ')} as required for #{name}" do
        _(required_in_metadata(name)).must_equal expected
      end
    end

    it "marks exactly the options that each operator requires" do
      operators_metadata.each_key do |name|
        _(required_in_metadata(name)).must_equal required_in_validations(name), name
      end
    end
  end

  describe "a subclass that requires inherited options" do
    let(:parent) do
      Class.new(ConceptQL::Operators::Operator) do
        option :first_opt, type: :string
        option :second_opt, type: :string
      end
    end

    let(:child) do
      Class.new(parent) do
        validate_required_options :first_opt, :second_opt
      end
    end

    def required(klass)
      klass.to_metadata("op")[:options].select { |_opt, h| h[:required] }.keys
    end

    it "marks both options as required for the subclass" do
      _(required(child)).must_equal %i[first_opt second_opt]
    end

    it "leaves the parent's options unmarked" do
      required(child)
      _(required(parent)).must_be_empty
      parent_options = parent.instance_variable_get(:@options)
      _(parent_options.values_at(:first_opt, :second_opt).map { |h| h[:required] }).must_equal [ nil, nil ]
    end
  end
end

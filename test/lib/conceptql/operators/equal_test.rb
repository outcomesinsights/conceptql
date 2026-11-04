# frozen_string_literal: true

require_relative "../../../helper"

# Equal compares only value_as_number, so the within option that it inherits
# from TemporalOperator has no effect. Ryan ruled on 2026-11-03 that within
# is unsupported on equal (seed conceptql-ufn): it is not in the metadata, and
# a statement that sets it fails validation. The other temporal operators
# keep it. No live database: the mock never answers a query.
describe "equal without within" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
  let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }
  let(:operands) { { left: %w[loinc 4548-4], right: %w[loinc 4548-4] } }

  def errors_for(statement)
    cdb.query(statement).annotate.last[:annotation][:errors]
  end

  it "leaves within out of the equal metadata" do
    _(operators_metadata["equal"][:options].keys).wont_include :within
  end

  it "keeps within in the before metadata" do
    _(operators_metadata["before"][:options].keys).must_include :within
  end

  it "rejects within on equal" do
    _(errors_for([ "equal", operands.merge(within: "30d") ])).must_equal [ [ "unsupported option", "within", "30d" ] ]
  end

  it "accepts equal without within" do
    _(errors_for([ "equal", operands ])).must_be_nil
  end

  it "treats a blank within on equal as not set" do
    _(errors_for([ "equal", operands.merge(within: " ") ])).must_be_nil
  end
end

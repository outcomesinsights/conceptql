# frozen_string_literal: true

require_relative "../../../helper"

# Ryan ruled on 2026-10-30 (seed conceptql-e8n) that count is deprecated.
# Every stream is a set, so count returns 1 for nearly every row. A
# statement that uses count still runs and returns the same rows, but
# annotation warns about it, and the metadata of count says deprecated
# (bead conceptql-0v4). No live database: the mock never answers a query.
describe "the deprecated count operator" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm) }

  def warnings_for(statement)
    cdb.query(statement).scope_annotate(skip_counts: true)[:warnings]
  end

  let(:deprecation) do
    [
      "deprecated operator",
      "count will become an error in a later release. " \
      "To count the events of each person, use numeric 1 and then sum."
    ]
  end

  it "warns on a count statement" do
    _(warnings_for([ "count", [ "icd9", "412" ] ])).must_equal("count" => [ deprecation ])
  end

  it "warns on count when count also has errors" do
    _(warnings_for([ "count" ])).must_equal("count" => [ deprecation ])
  end

  it "gives no warning for the numeric and sum idiom" do
    _(warnings_for([ "sum", [ "numeric", 1, [ "icd9", "412" ] ] ]).to_h).must_be_empty
  end

  # count has no category, so ConceptQL.metadata leaves it out, as it leaves
  # out sum. Ask each operator class for its metadata instead.
  describe "in the operator metadata" do
    let(:operators) { cdb.operators(:gdm) }

    def deprecated_in_metadata(name)
      operators.fetch(name).to_metadata(name)[:deprecated]
    end

    it "says count is deprecated" do
      _(deprecated_in_metadata("count")).must_equal true
    end

    it "does not say that any other operator is deprecated" do
      _(deprecated_in_metadata("sum")).must_be_nil
      _(operators.keys.reject { |name| deprecated_in_metadata(name).nil? }).must_equal [ "count" ]
    end
  end
end

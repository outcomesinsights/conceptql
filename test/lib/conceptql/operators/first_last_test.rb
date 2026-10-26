# frozen_string_literal: true

require_relative "../../../helper"

# First and Last inherit at_least and within from Occurrence, but with either
# option Occurrence's timed query returns every upstream row instead of one row
# per person. So the two options are not in their metadata, and a statement
# that sets one fails validation (bead conceptql-w7y). Occurrence keeps both.
# No live database: the mock never answers a query.
describe "first and last without at_least and within" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
  let(:operators_metadata) { ConceptQL.metadata(cdb)[:operators] }

  def errors_for(statement)
    cdb.query(statement).annotate.last[:annotation][:errors]
  end

  # Each CTE name ends in a random hex suffix
  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\h{32}\b/, "_HEX")
  end

  %w[first last].each do |name|
    it "leaves at_least and within out of the #{name} metadata" do
      _(operators_metadata[name][:options].keys).must_equal %i[label group_by_date]
    end

    it "rejects at_least and within on #{name}" do
      statement = [ name, %w[icd9 412], { at_least: "30d", within: "1y" } ]

      _(errors_for(statement)).must_equal [
        [ "unsupported option", "at_least", "30d" ],
        [ "unsupported option", "within", "1y" ]
      ]
    end

    it "treats a blank at_least or within on #{name} as not set" do
      plain = [ name, %w[icd9 412] ]
      blank = [ name, %w[icd9 412], { at_least: "", within: " " } ]

      _(errors_for(blank)).must_be_nil
      _(masked_sql(blank)).must_equal masked_sql(plain)
    end
  end

  it "keeps at_least and within in the occurrence metadata" do
    _(operators_metadata["occurrence"][:options].keys).must_equal %i[label at_least within group_by_date]
  end

  it "accepts at_least and within on occurrence" do
    _(errors_for([ "occurrence", 2, %w[icd9 412], { at_least: "30d", within: "1y" } ])).must_be_nil
  end
end

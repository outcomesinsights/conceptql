# frozen_string_literal: true

require_relative "../../../helper"

# Except has no `as` option. Before bead conceptql-dlq, a statement that set
# one passed validation and ran as a plain except, so a user who meant "cast
# both streams first" got other rows with no warning. Only `as` is rejected:
# Except still reads ignore_dates, and t_shank gives the options that
# tshank_only_options_metadata_test.rb lists, none of which Except declares.
# No live database: the mock never answers a query.
describe "except options" do
  let(:cdb) { ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm_wide) }
  let(:streams) { { left: %w[icd9 412], right: %w[cpt 99214] } }

  def errors_for(statement)
    cdb.query(statement).annotate.last[:annotation][:errors]
  end

  # Each CTE name ends in a random hex suffix
  def masked_sql(statement)
    cdb.query(statement).sql.gsub(/_\h{32}\b/, "_HEX")
  end

  it "rejects an as option and names it" do
    _(errors_for([ "except", streams.merge(as: "person") ])).must_equal [
      [ "unsupported option", "as", "person" ]
    ]
  end

  it "treats a blank as option as not set" do
    plain = [ "except", streams ]
    blank = [ "except", streams.merge(as: " ") ]

    _(errors_for(blank)).must_be_nil
    _(masked_sql(blank)).must_equal masked_sql(plain)
  end

  it "accepts ignore_dates" do
    _(errors_for([ "except", streams.merge(ignore_dates: true) ])).must_be_nil
  end

  it "accepts the t_shank-only options" do
    tshank = { only_columns: "person_id", except_columns: "start_date", join_columns: "person_id", invert_match: true }

    _(errors_for([ "except", streams.merge(tshank) ])).must_be_nil
  end

  it "keeps the except metadata unchanged" do
    _(ConceptQL.metadata(cdb)[:operators]["except"][:options].keys).must_equal %i[label left right]
  end
end

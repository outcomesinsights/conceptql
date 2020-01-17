require_relative "../../../helper"
require "conceptql"

describe ConceptQL::Operators::Selection::InformationPeriods do
  it "should appear for GDM" do
    _(ConceptQL::Operators.operators[:gdm]["information_periods"]).must_equal ConceptQL::Operators::Selection::InformationPeriods
  end

  it "should produce correct SQL under gdm" do
    cdb = ConceptQL::Database.new(Sequel.mock(host: :postgres), data_model: :gdm)
    sql_matches(cdb.query(["information_periods"]).sql, "information_periods_cql_view")
  end
end


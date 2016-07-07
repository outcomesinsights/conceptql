require_relative 'helper'

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    query(
      :foo
    ).annotate.must_equal(
      ["invalid", {:annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["invalid root operator", ":foo"]]}}]
    )
  end

  it "should handle query_cols for non-CDM tables" do
    query(
      [:from, "other_table"]
    ).operator.query_cols.must_equal(ConceptQL::Operators::SELECTED_COLUMNS)
  end
end


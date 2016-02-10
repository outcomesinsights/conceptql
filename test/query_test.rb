require_relative 'helper'

describe ConceptQL::Query do
  it "should handle errors in the root operator" do
    query(
      :foo
    ).annotate.must_equal(
      ["invalid", {:annotation=>{:errors=>["invalid root operator"]}}]
    )
  end
end


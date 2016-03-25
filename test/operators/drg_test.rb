require_relative '../helper'

describe ConceptQL::Operators::RevenueCode do
  it "should produce correct results" do
    criteria_ids(
      [:drg, '100']
    ).must_equal({})
  end

  it "should have the correct domain" do
    query([:drg, '100']).domains == [:procedure_occurrence]
  end
end


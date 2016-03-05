require_relative '../helper'

describe ConceptQL::Operators::RevenueCode do
  it "should produce correct results" do
    criteria_ids(
      [:revenue_code, '100']
    ).must_equal({})
  end

  it "should have the best procedure_type" do
    query([:revenue_code, '100']).types == [:procedure_occurrence]
  end
end


require_relative '../helper'

describe ConceptQL::Operators::RevenueCode do
  it "should produce correct results" do
    criteria_ids("revenue_code/crit_basic"
      [:drg, '100']
    ).must_equal({})
  end

  it "should have the correct domain" do
    domains("revenue_code/domains_drg100", [:drg, '100'])
  end
end


require_relative '../helper'

describe ConceptQL::Operators::RevenueCode do
  it "should produce correct results" do
    criteria_ids("revenue_code/crit_1",
      [:revenue_code, '100']
    )
  end

  it "should have the correct domain" do
    domains("revenue_code/domains_1", [:revenue_code, '100'])
  end
end


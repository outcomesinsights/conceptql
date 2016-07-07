require_relative '../helper'

describe ConceptQL::Operators::Hcpcs do
  it "should produce correct results" do
    criteria_ids("hcpcs/crit_A0382",
      [:hcpcs, 'A0382']
    )
  end
end

require_relative '../helper'

describe ConceptQL::Operators::Hcpcs do
  it "should produce correct results" do
    criteria_ids(
      hcpcs: 'A0382'
    ).must_equal("procedure_occurrence"=>[2453, 2706, 7318, 7446, 31137])
  end
end

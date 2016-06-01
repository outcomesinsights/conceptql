require_relative '../helper'

describe ConceptQL::Operators::Hcpcs do
  it "should produce correct results" do
    criteria_ids(
      [:hcpcs, 'A0382']
    ).must_equal("procedure_occurrence"=>[12987, 13072, 18844, 20888])
  end
end

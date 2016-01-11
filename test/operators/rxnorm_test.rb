require_relative '../helper'

describe ConceptQL::Operators::Rxnorm do
  it "should produce correct results" do
    criteria_ids(
      rxnorm: '672568'
    ).must_equal("drug_exposure"=>[2])
  end
end


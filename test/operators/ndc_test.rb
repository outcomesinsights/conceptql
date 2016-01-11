require_relative '../helper'

describe ConceptQL::Operators::Ndc do
  it "should produce correct results" do
    criteria_ids(
      ndc: '12745010902'
    ).must_equal("drug_exposure"=>[1])
  end
end

require_relative '../helper'

describe ConceptQL::Operators::Rxnorm do
  it "should produce correct results" do
    criteria_ids("rxnorm/crit_1",
      [:rxnorm, '672568']
    )
  end
end


require_relative '../helper'

describe ConceptQL::Operators::Ndc do
  it "should produce correct results" do
    criteria_ids("ndc/crit_basic",
      [:ndc, '12745010902']
    )
  end
end

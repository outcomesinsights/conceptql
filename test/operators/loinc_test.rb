require_relative '../helper'

describe ConceptQL::Operators::Loinc do
  it "should produce correct results" do
    criteria_ids("loinc/crit_basic",
      [:loinc, '13298-5']
    )
  end
end

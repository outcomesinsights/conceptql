require_relative '../helper'

describe ConceptQL::Operators::Filter do
  it "should produce correct results" do
    criteria_ids("filter/crit_1"
      [:filter, {:left=>[:icd9, "411", "412"], :right=>[:icd9, "412", "413"]}]
    )
  end
end


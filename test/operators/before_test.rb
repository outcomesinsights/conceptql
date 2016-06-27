require_relative '../helper'

describe ConceptQL::Operators::Before do
  it "should produce correct results" do
    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"]}]
    ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8618, 9882, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 32104, 32981])

    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:first, [:icd9, "401.9"]]}]
    ).must_equal("condition_occurrence"=>[5751, 21006, 24721])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"], :within=>'30d'}]
    ).must_equal("condition_occurrence"=>[13741, 17774, 31542])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"], :occurrences=>1}]
    ).must_equal("condition_occurrence"=>[1829, 17774, 20037, 24471, 24721, 25417, 25888, 28188, 31542])
  end
end

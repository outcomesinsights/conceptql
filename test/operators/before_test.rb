require_relative '../helper'

describe ConceptQL::Operators::Before do
  it "should produce correct results" do
    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:icd9, "401.9"]}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 3995, 4545, 4710, 5069, 5582, 8725, 10403, 10590, 11135, 11589, 11800, 13234, 13893, 14604, 14702, 14854, 14859, 17103, 17593, 23234, 23411, 24627, 25492, 26245, 27343, 37521, 38787, 52644, 52675, 53214, 53216, 53251, 53733, 53801, 55383, 56352, 56634, 56970, 57089, 57705, 58271, 58448, 58596, 58610, 58623, 59732, 59760, 59785])

    criteria_ids(
      [:before, {:left=>[:icd9, "412"], :right=>[:first, [:icd9, "401.9"]]}]
    ).must_equal("condition_occurrence"=>[8725, 11589, 37521, 58271])
  end
end



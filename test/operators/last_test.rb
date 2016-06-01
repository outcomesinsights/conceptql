require_relative '../helper'

describe ConceptQL::Operators::Last do
  it "should produce correct results" do
    criteria_ids(
      [:last, [:icd9, "412"]]
    ).must_equal("condition_occurrence"=>[2151, 2428, 4545, 4710, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 13234, 13893, 14604, 17103, 17593, 23234, 23411, 25492, 27343, 37521, 38787, 50019, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 55383, 56352, 56970, 57089, 57705, 58271, 58596, 58610, 58623, 59732, 59760, 59785])
  end
end


require_relative '../helper'

describe ConceptQL::Operators::Occurrence do
  it "should produce correct results" do
    criteria_ids(
      [:occurrence, 2, [:icd9, "412"]]
    ).must_equal("condition_occurrence"=>[4710, 10403, 10590, 11228, 13893, 14604, 17593, 27343, 50933, 53630, 53733, 56970, 58610])

    criteria_ids(
      [:occurrence, 2, [:icd9, "412"], {:unique=>true}]
    ).must_equal({})

    criteria_ids(
      [:occurrence, -1, [:icd9, "412"], {:unique=>true}]
    ).must_equal("condition_occurrence"=>[2151, 2428, 4545, 4710, 5263, 5582, 8725, 10403, 10590, 11135, 11228, 13234, 13893, 14604, 17103, 17593, 23234, 23411, 25492, 27343, 37521, 38787, 50019, 52644, 52675, 53214, 53216, 53251, 53630, 53733, 55383, 56352, 56970, 57089, 57705, 58271, 58596, 58610, 58623, 59732, 59760, 59785])
  end

  it "should handle errors when annotating" do
    query(
      [:occurrence]
    ).annotate.must_equal(
      ["occurrence", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["has no upstream"], ["has no arguments"]]}, :name=>"Nth Occurrence"}]
    )
  end

  it "should have a unique name per CTE" do
    criteria_counts([:union, [:first, [:icd9,  "412"] ], [:first, [:icd9,  "410"] ]])
  end
end

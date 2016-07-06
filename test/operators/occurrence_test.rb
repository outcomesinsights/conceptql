require_relative '../helper'

describe ConceptQL::Operators::Occurrence do
  it "should produce correct results" do
    criteria_ids(
      [:occurrence, 2, [:icd9, "412"]]
    ).must_equal("condition_occurrence"=>[1829, 10196, 17774, 20005, 21619, 24437, 24707, 25309, 25888, 28188, 31542, 31877])

    criteria_ids(
      [:occurrence, 2, [:icd9, "412"], {:unique=>true}]
    ).must_equal({})

    criteria_ids(
      [:occurrence, -1, [:icd9, "412"], {:unique=>true}]
    ).must_equal("condition_occurrence"=>[1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17774, 18412, 18555, 19736, 20005, 21006, 21619, 22875, 22933, 24437, 24707, 24989, 25309, 25888, 26766, 27388, 28188, 30831, 31542, 31792, 31877, 32463, 32981])
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

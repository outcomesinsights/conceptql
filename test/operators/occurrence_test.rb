require_relative '../helper'

describe ConceptQL::Operators::Occurrence do
  it "should produce correct results" do
    criteria_ids(
      [:occurrence, 2, [:icd9, "412"]]
    ).must_equal("condition_occurrence"=>[1829, 10196, 17774, 20005, 21619, 24437, 24707, 25309, 25888, 28188, 31542, 31877])
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

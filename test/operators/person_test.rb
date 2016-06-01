require_relative '../helper'

describe ConceptQL::Operators::Person do
  it "should produce correct results" do
    criteria_ids(
      [:person, [:icd9, "412"]]
    ).must_equal("person"=>[11, 17, 37, 53, 59, 64, 71, 75, 79, 86, 88, 91, 94, 104, 107, 108, 128, 146, 149, 158, 160, 168, 173, 180, 183, 190, 191, 205, 206, 207, 209, 212, 215, 222, 226, 231, 251, 255, 258, 260, 266, 270])

    criteria_counts(
      [:person]
    ).must_equal("person"=>250)
  end

  it "should handle errors when annotating" do
    query(
      [:person, [:icd9, "412"], [:icd9, "412"]]
    ).annotate.must_equal(
      ["person",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:counts=>{:person=>{:n=>0, :rows=>0}}, :errors=>[["has multiple upstreams"]]}}]
    )

    query(
      [:person, "412"]
    ).annotate.must_equal(
      ["person",
       "412",
       {:annotation=>{:counts=>{:person=>{:n=>0, :rows=>0}}, :errors=>[["has arguments"]]}}]
    )
  end
end

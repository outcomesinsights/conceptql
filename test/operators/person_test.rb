require_relative '../helper'

describe ConceptQL::Operators::Person do
  it "should produce correct results" do
    criteria_ids(
      [:person, [:icd9, "412"]]
    ).must_equal("person"=>[17, 37, 53, 59, 64, 71, 75, 79, 86, 88, 91, 104, 108, 128, 146, 149, 158, 160, 168, 173, 180, 183, 190, 191, 206, 207, 209, 212, 215, 222, 226, 231, 251, 255, 258, 260, 266, 270])

    criteria_counts(
      [:person, true]
    ).must_equal("person"=>250)
  end

  it "should handle errors when annotating" do
    query(
      [:person, [:icd9, "412"], [:icd9, "412"]]
    ).annotate.must_equal(
      ["person",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:errors=>[["has multiple upstreams"]]}}]
    )
  end
end

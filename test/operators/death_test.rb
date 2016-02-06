require_relative '../helper'

describe ConceptQL::Operators::Death do
  it "should produce correct results" do
    criteria_ids(
      [:death, true]
    ).must_equal("death"=>[177])

    criteria_ids(
      [:death, [:person, true]]
    ).must_equal("death"=>[177])
  end

  it "should handle errors when annotating" do
    query(
      [:death, [:person, true], [:icd9, "412"]]
    ).annotate.must_equal(
      ["death",
       ["person", true, {:annotation=>{:person=>{:rows=>250, :n=>250}}}],
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:errors=>[["has multiple upstreams"]]}}]
    )
  end
end

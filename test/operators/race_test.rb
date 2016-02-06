require_relative '../helper'

describe ConceptQL::Operators::Race do
  it "should produce correct results" do
    criteria_ids(
      [:race, 'Black or African American']
    ).must_equal("person"=>[6, 10, 17, 18, 21, 66, 69, 73, 106, 109, 113, 115, 117, 129, 135, 140, 163, 198, 209, 219, 226, 230, 243, 260])
  end

  it "should handle errors when annotating" do
    query(
      [:race, 'Black or African American', [:icd9, "412"]]
    ).annotate.must_equal(
      ["race",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       "Black or African American",
       {:annotation=>{:errors=>[["has upstreams"]]}}]
    )
  end
end

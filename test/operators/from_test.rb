require_relative '../helper'

describe ConceptQL::Operators::From do
  it "should produce correct results" do
    dataset(
      [:from, 'person']
    ).count.must_equal(250)

    dataset(
      [:from, 'observation_period']
    ).count.must_equal(1)

    dataset(
      [:from, 'condition_occurrence']
    ).count.must_equal(34044)
  end

  it "should handle errors when annotating" do
    query(
      [:from, [:icd9, "412"]]
    ).annotate.must_equal(
      ["from",
       ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:errors=>[["has upstreams"]]}}]
    )
  end
end

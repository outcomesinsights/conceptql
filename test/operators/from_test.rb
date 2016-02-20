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
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       {:annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["has upstreams"], ["has no arguments"]]}}]
    )

    query(
      [:from, 'person', 'observation_period']
    ).annotate.must_equal(
      ["from",
       'person',
       'observation_period',
       {:annotation=>{:counts=>{:observation_period=>{:n=>0, :rows=>0}}, :errors=>[["has multiple arguments"]]}}]
    )
  end
end

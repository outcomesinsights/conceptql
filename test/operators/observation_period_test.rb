require_relative '../helper'

describe ConceptQL::Operators::ObservationPeriod do
  it "should produce correct results" do
    criteria_ids(
      [:observation_period, [:icd9, '412']]
    ).must_equal("observation_period"=>[7, 17, 26, 28, 33, 37, 39, 45, 55, 56, 68, 79, 87, 88, 90, 92, 96, 100, 101, 111, 112, 113, 121, 136, 140, 142, 143])

    criteria_ids(
      [:observation_period, [:gender, 'Male']]
    ).must_equal("observation_period"=>[1, 3, 4, 5, 9, 12, 13, 18, 20, 23, 26, 29, 30, 31, 32, 35, 38, 41, 46, 47, 49, 52, 56, 57, 58, 59, 61, 62, 63, 66, 67, 68, 69, 70, 74, 77, 78, 79, 81, 82, 83, 84, 87, 93, 94, 95, 96, 99, 101, 102, 105, 110, 111, 112, 113, 118, 122, 123, 127, 131, 134, 136, 143, 144, 146, 147, 148, 149, 152, 153, 155, 156])

    criteria_ids(
      [:observation_period, [:gender, 'Female']]
    ).must_equal({})
  end

  it "should handle errors when annotating" do
    query(
      [:observation_period, [:icd9, '412'], [:gender, 'Male']]
    ).annotate.must_equal(
      ["observation_period",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
       {:annotation=>{:counts=>{:observation_period=>{:n=>0, :rows=>0}}, :errors=>[["has multiple upstreams"]]}}]
    )

    query(
      [:observation_period, 1, [:gender, 'Male']]
    ).annotate.must_equal(
      ["observation_period",
       ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
       1,
       {:annotation=>{:counts=>{:observation_period=>{:n=>0, :rows=>0}}, :errors=>[["has arguments"]]}}]
    )
  end
end

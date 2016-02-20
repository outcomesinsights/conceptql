require_relative '../helper'

describe ConceptQL::Operators::OneInTwoOut do
  it "should produce correct results" do
    criteria_ids(
      [:one_in_two_out, [:icd9, "412"], {:gap=>30, :blah=>true}]
    ).must_equal("visit_occurrence"=>[757, 2705, 3847, 4378, 6640, 7810, 8108, 8806, 9544, 10786, 10894, 11198, 11412, 11783, 12370, 13783, 13972])
  end

  it "should handle errors when annotating" do
    query(
      [:one_in_two_out, {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out",{:gap=>30, :blah=>true,
                         :annotation=>{:counts=>{:visit_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has no upstream"]]}}]
    )

    query(
      [:one_in_two_out, 1, {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out", 1, {:gap=>30, :blah=>true,
                             :annotation=>{:counts=>{:visit_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has no upstream"], ["has arguments"]]}}]
    )

    query(
      [:one_in_two_out, [:icd9, "412"], [:icd9, "412"], {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       {:gap=>30, :blah=>true,
        :annotation=>{:counts=>{:visit_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has multiple upstreams"]]}}]
    )
  end
end

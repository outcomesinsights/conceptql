require_relative '../helper'

describe ConceptQL::Operators::OneInTwoOut do
  it "should produce correct results" do
    criteria_ids(
      [:one_in_two_out, [:icd9, "412"], {:min_gap=>30, :blah=>true}]
    ).must_equal("condition_occurrence"=>[1829, 6083, 8618, 9882, 15149, 17774, 18412, 20005, 21619, 24437, 24707, 25309, 25888, 26766, 28188, 31542, 31877])
  end

  it "should treat non-conditions as inpatient" do
    criteria_ids(
      [:one_in_two_out, [:hcpcs, 'A0382'] , {:min_gap=>30}]
    ).must_equal("procedure_occurrence"=>[2706, 7446, 31137])

  end

  it "should handle errors when annotating" do
    query(
      [:one_in_two_out, {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out",{:gap=>30, :blah=>true,
                         :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["has no upstream"]]}}]
    )

    query(
      [:one_in_two_out, 1, {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out", 1, {:gap=>30, :blah=>true,
                             :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["has no upstream"], ["has arguments", [1]]]}}]
    )

    query(
      [:one_in_two_out, [:icd9, "412"], [:icd9, "412"], {:gap=>30, :blah=>true}]
    ).annotate.must_equal(
      ["one_in_two_out",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
       {:gap=>30, :blah=>true,
        :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has multiple upstreams", ["icd9", "icd9"]]]}}]
    )
  end
end

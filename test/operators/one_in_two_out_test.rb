require_relative '../helper'

describe ConceptQL::Operators::OneInTwoOut do
  it "should produce correct results" do
    criteria_ids(
      [:one_in_two_out, [:icd9, "412"], {:gap=>30, :blah=>true}]
    ).must_equal("visit_occurrence"=>[1789, 3422, 3705, 5069, 10344, 11589, 11800, 51306, 51336, 51337, 51366, 51380, 51382, 51423, 51440, 51843, 53228])
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
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       {:gap=>30, :blah=>true,
        :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has multiple upstreams", ["icd9", "icd9"]]]}}]
    )
  end
end

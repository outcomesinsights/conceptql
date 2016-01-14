require_relative '../helper'

describe ConceptQL::Operators::OneInTwoOut do
  it "should produce correct results" do
    criteria_ids(
      [:one_in_two_out, [:icd9, "412"], {:gap=>30, :blah=>true}]
    ).must_equal("visit_occurrence"=>[757, 2705, 3847, 4378, 6640, 7810, 8108, 8806, 9544, 10786, 10894, 11198, 11412, 11783, 12370, 13783, 13972])
  end
end

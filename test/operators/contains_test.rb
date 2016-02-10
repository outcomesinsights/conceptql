require_relative '../helper'

describe ConceptQL::Operators::Contains do
  it "should produce correct results" do
    criteria_ids(
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-20"}]}]
    ).must_equal("condition_occurrence"=>[26766])

    criteria_ids(
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]}]
    ).must_equal({})

    criteria_ids(
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-22"}]}]
    ).must_equal({})
  end
end

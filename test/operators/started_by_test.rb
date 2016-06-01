require_relative '../helper'

describe ConceptQL::Operators::StartedBy do
  it "should produce correct results" do
    criteria_ids(
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-20"}]}]
    ).must_equal("condition_occurrence"=>[52675])

    criteria_ids(
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-21"}]}]
    ).must_equal({})

    criteria_ids(
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-22"}]}]
    ).must_equal({})
  end
end



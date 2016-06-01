require_relative '../helper'

describe ConceptQL::Operators::OverlappedBy do
  it "should produce correct results" do
    criteria_ids(
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]}]
    ).must_equal("condition_occurrence"=>[52675])

    criteria_ids(
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-20"}]}]
    ).must_equal({})

    criteria_ids(
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-12", :end=>"2008-03-23"}]}]
    ).must_equal("condition_occurrence"=>[52644])

    criteria_ids(
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-12", :end=>"2008-03-13"}]}]
    ).must_equal({})
  end
end

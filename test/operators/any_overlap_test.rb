require_relative '../helper'

describe ConceptQL::Operators::AnyOverlap do
  it "should produce correct results" do
    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
    ).must_equal("condition_occurrence"=>[4359, 8397, 10443, 13741, 17774, 21619, 24437, 24989, 28188, 31542, 31877])

    criteria_ids(
      [:any_overlap,
       {:left=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :right=>[:icd9, "412"]}]
    ).must_equal("person"=>[37, 75, 88, 108, 149, 183, 206, 209, 231, 255, 260])
  end
end

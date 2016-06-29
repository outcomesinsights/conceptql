require_relative '../helper'

describe ConceptQL::Operators::AnyOverlap do
  it "should produce correct results" do
    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
    ).must_equal("condition_occurrence"=>[2151, 4710, 5263, 5582, 10590, 11228, 13234, 25492, 27343, 38787, 53630, 58610])

    criteria_ids(
      [:any_overlap,
       {:left=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :right=>[:icd9, "412"]}]
    ).must_equal("person"=>[37, 75, 88, 107, 108, 149, 183, 206, 209, 231, 255, 260])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :within=>'-100d'}]
    ).must_equal("condition_occurrence"=>[10443, 13741, 24989, 31877])
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :at_least =>'-200d'}]
    ).must_equal("condition_occurrence"=>[13741, 24989])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :occurrences=>1}]
    ).must_equal({})

    criteria_ids(
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :occurrences=>0}]
    ).must_equal("condition_occurrence"=>[4359, 8397, 10443, 13741, 17774, 21619, 24437, 24989, 28188, 31542, 31877])
  end
end

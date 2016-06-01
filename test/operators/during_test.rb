require_relative '../helper'

describe ConceptQL::Operators::During do
  it "should produce correct results" do
    criteria_ids(
      [:during,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
    ).must_equal("condition_occurrence"=>[2151, 4710, 5263, 5582, 10590, 11228, 13234, 25492, 27343, 38787, 53630, 58610])

    criteria_ids(
      [:during,
       {:left=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :right=>[:icd9, "412"]}]
    ).must_equal({})
  end
end

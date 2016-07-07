require_relative '../helper'

describe ConceptQL::Operators::During do
  it "should produce correct results" do
    criteria_ids("during/crit_1",
      [:during,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
    )

    criteria_ids("during/crit_2",
      [:during,
       {:left=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :right=>[:icd9, "412"]}]
    )
  end
end

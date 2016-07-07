require_relative '../helper'

describe ConceptQL::Operators::Contains do
  it "should produce correct results" do
    criteria_ids("contains/crit_1",
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-20"}]}]
    )

    criteria_ids("contains/crit_2",
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]}]
    )

    criteria_ids("contains/crit_3",
      [:contains,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-22"}]}]
    )
  end
end

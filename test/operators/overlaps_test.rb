require_relative '../helper'

describe ConceptQL::Operators::Overlaps do
  it "should produce correct results" do
    criteria_ids("overlaps/crit_1",
      [:overlaps,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-21", :end=>"2008-03-23"}]}]
    )

    criteria_ids("overlaps/crit_2",
      [:overlaps,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-20"}]}]
    )

    criteria_ids("overlaps/crit_3",
      [:overlaps,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-22", :end=>"2008-03-24"}]}]
    )

    criteria_ids("overlaps/crit_4",
      [:overlaps,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-12", :end=>"2008-03-13"}]}]
    )
  end
end


require_relative '../helper'

describe ConceptQL::Operators::StartedBy do
  it "should produce correct results" do
    criteria_ids("started_by/crit_1",
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-20"}]}]
    )

    criteria_ids("started_by/crit_2",
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-21"}]}]
    )

    criteria_ids("started_by/crit_3",
      [:started_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2008-03-22"}]}]
    )
  end
end



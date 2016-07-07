require_relative '../helper'

describe ConceptQL::Operators::OverlappedBy do
  it "should produce correct results" do
    criteria_ids("overlapped_by/crit_1",
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]}]
    )

    criteria_ids("overlapped_by/crit_2",
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-15", :end=>"2008-03-20"}]}]
    )

    criteria_ids("overlapped_by/crit_3",
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-12", :end=>"2008-03-23"}]}]
    )

    criteria_ids("overlapped_by/crit_4",
      [:overlapped_by,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-12", :end=>"2008-03-13"}]}]
    )
  end
end

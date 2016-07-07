require_relative '../helper'

describe ConceptQL::Operators::DateRange do
  it "should produce correct results" do
    criteria_counts("date_range/count_1",
      [:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]
    )

    criteria_counts("date_range/count_2",
      [:date_range, {:start=>"START", :end=>"END"}]
    )
  end

  it "#annotate should work correctly" do
    annotate("date_range/anno_1",
      [:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]
    )
  end

  it "should handle errors when annotating" do
    annotate("date_range/anno_no_upstreams",
      [:date_range, [:icd9, "412"], {:start=>"START", :end=>"END"}]
    )

    annotate("date_range/anno_extra_argument",
      [:date_range, "412", {:start=>"START", :end=>"END"}]
    )

    annotate("date_range/anno_invalid_argument",
      [:date_range, {:start=>1, :end=>2}]
    )

    annotate("date_range/anno_missing_argument1",
      [:date_range, {:end=>"END"}]
    )

    annotate("date_range/anno_missing_argument2",
      [:date_range, {:start=>"START"}]
    )
  end
end

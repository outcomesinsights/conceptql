require_relative '../helper'

describe ConceptQL::Operators::AnyOverlap do
  it "should produce correct results" do
    criteria_ids("any_overlap/crit_basic1",
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}]}]
    )

    criteria_ids("any_overlap/crit_basic2",
      [:any_overlap,
       {:left=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :right=>[:icd9, "412"]}]
    )
  end

  it "should produce correct results when using :within option" do
    criteria_ids("any_overlap/crit_within",
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :within=>'-100d'}]
    )
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids("any_overlap/crit_occurrences1",
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :occurrences=>1}]
    )

    criteria_ids("any_overlap/crit_occurrences2",
      [:any_overlap,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2010-01-01", :end=>"2010-12-31"}],
        :occurrences=>0}]
    )
  end
end

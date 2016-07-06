require_relative '../helper'

describe ConceptQL::Operators::TrimDateStart do
  it "should produce correct results" do
    criteria_ids("trim_date_start/crit_1",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-12-01"}]}]
    )

    criteria_ids("trim_date_start/crit_2",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2012-01-21"}]}]
    )

    criteria_ids("trim_date_start/crit_3",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}]}]
    )
  end

  it "should produce correct results when using :within option" do
    criteria_ids("trim_date_start/crit_within",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :within=>'3d'}]
    )
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids("trim_date_start/crit_at_least",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :at_least=>'30d'}]
    )
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids("trim_date_start/crit_occurrences_1",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :occurrences=>1}]
    )

    criteria_ids("trim_date_start/crit_occurrences_2",
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :occurrences=>0}]
    )
  end
end

require_relative '../helper'

describe ConceptQL::Operators::TrimDateEnd do
  it "should produce correct results" do
    criteria_ids("trim_date_end/crit_1",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-01-08", :end=>"2010-12-01"}]}]
    )

    criteria_ids("trim_date_end/crit_2",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-01-06", :end=>"2012-12-01"}]}]
    )

    criteria_ids("trim_date_end/crit_3",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}]}]
    )
  end

  it "should produce correct results when using :within option" do
    criteria_ids("trim_date_end/crit_within",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :within=>'3d'}]
    )
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids("trim_date_end/crit_at_least",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :at_least=>'30d'}]
    )
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids("trim_date_end/crit_occurrences_1",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :occurrences=>1}]
    )

    criteria_ids("trim_date_end/crit_occurrences_2",
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :occurrences=>0}]
    )
  end
end

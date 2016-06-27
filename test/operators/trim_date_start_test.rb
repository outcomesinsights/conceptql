require_relative '../helper'

describe ConceptQL::Operators::TrimDateStart do
  it "should produce correct results" do
    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-12-01"}]}]
    ).must_equal("condition_occurrence"=>[21619])

    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2012-01-21"}]}]
    ).must_equal({})

    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}]}]
    ).must_equal("condition_occurrence"=>[17774, 21619])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :within=>'3d'}]
    ).must_equal("condition_occurrence"=>[17774])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :occurrences=>1}]
    ).must_equal({})

    criteria_ids(
      [:trim_date_start,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-03-14", :end=>"2010-11-22"}],
        :occurrences=>0}]
    ).must_equal("condition_occurrence"=>[17774, 21619])
  end
end

require_relative '../helper'

describe ConceptQL::Operators::TrimDateEnd do
  it "should produce correct results" do
    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-01-08", :end=>"2010-12-01"}]}]
    ).must_equal("condition_occurrence"=>[58271])

    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-01-06", :end=>"2012-12-01"}]}]
    ).must_equal({})

    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}]}]
    ).must_equal("condition_occurrence"=>[11589, 58271])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :within=>'3d'}]
    ).must_equal("condition_occurrence"=>[24721])
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :at_least=>'30d'}]
    ).must_equal("condition_occurrence"=>[21006])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :occurrences=>1}]
    ).must_equal({})

    criteria_ids(
      [:trim_date_end,
       {:left=>[:icd9, "412"],
        :right=>[:date_range, {:start=>"2008-02-17", :end=>"2010-12-01"}],
        :occurrences=>0}]
    ).must_equal("condition_occurrence"=>[21006, 24721])
  end
end

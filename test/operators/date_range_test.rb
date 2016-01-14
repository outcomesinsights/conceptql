require_relative '../helper'

describe ConceptQL::Operators::DateRange do
  it "should produce correct results" do
    criteria_counts(
      [:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]
    ).must_equal("person"=>250)

    criteria_counts(
      [:date_range, {:start=>"START", :end=>"END"}]
    ).must_equal("person"=>250)
  end
end

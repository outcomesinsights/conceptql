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

  it "#annotate should work correctly" do
    query(
      [:date_range, {:start=>"2008-03-13", :end=>"2008-03-20"}]
    ).annotate.must_equal(["date_range", {:start=>"2008-03-13", :end=>"2008-03-20",
                                          :annotation=>{:counts=>{:person=>{:rows=>250, :n=>250}}}}])
  end

  it "should handle errors when annotating" do
    query(
      [:date_range, [:icd9, "412"], {:start=>"START", :end=>"END"}]
    ).annotate.must_equal(
      ["date_range",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
       {:start=>"START", :end=>"END",
        :annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["has upstreams", ["icd9"]]]}}]
    )

    query(
      [:date_range, "412", {:start=>"START", :end=>"END"}]
    ).annotate.must_equal(
      ["date_range",
       "412",
       {:start=>"START", :end=>"END",
        :annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["has arguments", ["412"]]]}}]
    )

    query(
      [:date_range, {:start=>1, :end=>2}]
    ).annotate.must_equal(
      ["date_range",
       {:start=>1, :end=>2,
        :annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["wrong option format", "start"], ["wrong option format", "end"]]}}]
    )

    query(
      [:date_range, {:end=>"END"}]
    ).annotate.must_equal(
      ["date_range",
       {:end=>"END",
        :annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["required option not present", "start"]]}}]
    )

    query(
      [:date_range, {:start=>"START"}]
    ).annotate.must_equal(
      ["date_range",
       {:start=>"START",
        :annotation=>{:counts=>{:person=>{:rows=>0, :n=>0}}, :errors=>[["required option not present", "end"]]}}]
    )
  end
end

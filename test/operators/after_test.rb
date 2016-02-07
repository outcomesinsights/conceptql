require_relative '../helper'

describe ConceptQL::Operators::After do
  it "should produce correct results" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal("condition_occurrence"=>[5751, 6083, 10865, 13741, 15149, 17041, 17772, 17774, 18412, 21619, 21627, 22933, 24437, 24471, 24707, 24721, 25309, 25417, 25875, 25888, 26766, 28177, 28188, 30831, 31877, 32104, 32463, 32981])
  end

  it "should handle upstream errors when annotating" do
    query(
      [:after,
       {:right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {:right=>["time_window",
                 ["gender", "Male", {:annotation=>{:person=>{:rows=>126, :n=>126}}}],
                 {:start=>"50y", :end=>"50y", :annotation=>{:person=>{:rows=>126, :n=>126}}}],
        :annotation=>{:errors=>[["no left upstream"]]}}]
    )

    query(
      [:after,
       {:left=>[:icd9, "412"]}]
    ).annotate.must_equal(
      ["after",
       {:left=>["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
        :annotation=>{:errors=>[["no right upstream"]]}}]
    )

    query(
      [:after,
       {:left=>[:union],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {:left=>["union", {:annotation=>{:errors=>[["has no upstream"]]}}],
        :right=>["time_window",
                 ["gender", "Male", {:annotation=>{:person=>{:rows=>126, :n=>126}}}],
                 {:start=>"50y", :end=>"50y", :annotation=>{:person=>{:rows=>126, :n=>126}}}],
        :annotation=>{}}]
    )

    query(
      [:after,
       1,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {:left=>["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
        :right=>["time_window",
                 ["gender", "Male",{:annotation=>{:person=>{:rows=>126, :n=>126}}}],
                 {:start=>"50y", :end=>"50y", :annotation=>{:person=>{:rows=>126, :n=>126}}}]},
       1,
       {:annotation=>{:errors=>[["has arguments"]]}}]
    )
  end
end

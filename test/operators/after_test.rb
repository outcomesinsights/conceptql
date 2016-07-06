require_relative '../helper'

describe ConceptQL::Operators::After do
  it "should produce correct results" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal("condition_occurrence"=>[5751, 6083, 10865, 13741, 15149, 17041, 17772, 17774, 18412, 21619, 21627, 22933, 24437, 24471, 24707, 24721, 25309, 25417, 25875, 25888, 26766, 28177, 28188, 30831, 31877, 32104, 32463, 32981])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :within=>"3000d"}]
    ).must_equal("condition_occurrence"=>[32104, 32981])
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :at_least=>"15000d"}]
    ).must_equal("condition_occurrence"=>[24707, 24721, 26766])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :occurrences=>1}]
    ).must_equal("condition_occurrence"=>[17774, 21619, 24437, 24707, 25309, 25888, 28188, 31877])
  end

  it "should handle upstream errors when annotating" do
    query(
      [:after,
       {:left=>"412",
        :right=>:time_window}]
    ).annotate.must_equal(
      ["after", {:left=>"412", :right=>:time_window, :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["wrong option format", "left"], ["wrong option format", "right"]]}}]
    )

    query(
      [:after,
       {:right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {:right=>["time_window",
                 ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
                 {:start=>"50y", :end=>"50y", :annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["required option not present", "left"]]}}]
    )

    query(
      [:after,
       {:left=>[:icd9, "412"]}]
    ).annotate.must_equal(
      ["after",
       {:left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        :annotation=>{:counts=>{:condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["required option not present", "right"]]}}]
    )

    query(
      [:after,
       {:left=>[:union],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {:left=>["union", {
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["has no upstream"]]}}],
        :right=>["time_window",
                 ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
                 { :annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}, :start=>"50y", :end=>"50y",}],
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}}}]
    )

    query(
      [:after,
       1,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).annotate.must_equal(
      ["after",
       {
        :left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        :right=>["time_window",
                 ["gender", "Male",{:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
                 {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}, :start=>"50y", :end=>"50y"}]},
       1,
       { :annotation=>{:counts=>{:condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["has arguments", [1]]]}}]
    )

    # Check that within, at_least, and occurrences are checked
    query(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:icd9, "412"],
        :within=> 'abc',
        :at_least=> 'cba',
        :occurrences=> 'bac'
      }]
    ).annotate.must_equal(
      ["after", {
        :left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        :right=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        :within=> 'abc',
        :at_least=> 'cba',
        :occurrences=> 'bac',
        :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}},
                      :errors=>[["wrong option format", "within"], ["wrong option format", "at_least"], ["wrong option format", "occurrences"]]
        }
      }]
    )
  end
end

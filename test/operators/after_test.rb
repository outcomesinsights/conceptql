require_relative '../helper'

describe ConceptQL::Operators::After do
  it "should produce correct results" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal("condition_occurrence"=>[3995, 5069, 8725, 10403, 10590, 11228, 11589, 11800, 13893, 14702, 14854, 23411, 24627, 25492, 26245, 27343, 38787, 50019, 50933, 52644, 52675, 53214, 53216, 53630, 55383, 56970, 57705, 58596, 58610, 58623, 59732, 59785])
  end

  it "should produce correct results when using :within option" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :within=>"3000d"}]
    ).must_equal("condition_occurrence"=>[32104, 32981])
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids(
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :occurrences=>1}]
    ).must_equal("condition_occurrence"=>[17772, 21627, 24471, 24721, 25309, 25888, 28177, 32104])
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
       {:left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
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
        :left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
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
        :left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
        :right=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>55, :n=>42}}}, :name=>"ICD-9 CM"}],
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

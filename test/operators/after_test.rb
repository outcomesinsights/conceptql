require_relative '../helper'

describe ConceptQL::Operators::After do
  it "should produce correct results" do
    criteria_ids("after/crit_basic",
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    )
  end

  it "should produce correct results when using :within option" do
    criteria_ids("after/crit_within",
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
    criteria_ids("after/crit_occurrences",
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :occurrences=>1}]
    ).must_equal("condition_occurrence"=>[17774, 21619, 24437, 24707, 25309, 25888, 28188, 31877])
  end

  it "should handle upstream errors when annotating" do
    annotate("after/anno_1",
      [:after,
       {:left=>"412",
        :right=>:time_window}]
    ).must_equal(
      ["after", {:left=>"412", :right=>:time_window, :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["wrong option format", "left"], ["wrong option format", "right"]]}}]
    )

    annotate("after/anno_2",
      [:after,
       {:right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal(
      ["after",
       {:right=>["time_window",
                 ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
                 {:start=>"50y", :end=>"50y", :annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["required option not present", "left"]]}}]
    )

    annotate("after/anno_3",
      [:after,
       {:left=>[:icd9, "412"]}]
    ).must_equal(
      ["after",
       {:left=>["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        :annotation=>{:counts=>{:condition_occurrence=>{:n=>0, :rows=>0}}, :errors=>[["required option not present", "right"]]}}]
    )

    annotate("after/anno_4",
      [:after,
       {:left=>[:union],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal(
      ["after",
       {:left=>["union", {
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}, :errors=>[["has no upstream"]]}}],
        :right=>["time_window",
                 ["gender", "Male", {:annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}}],
                 { :annotation=>{:counts=>{:person=>{:rows=>126, :n=>126}}}, :start=>"50y", :end=>"50y",}],
        :annotation=>{:counts=>{:invalid=>{:n=>0, :rows=>0}}}}]
    )

    annotate("after/anno_5",
      [:after,
       1,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    ).must_equal(
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
    annotate("after/anno_6",
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:icd9, "412"],
        :within=> 'abc',
        :at_least=> 'cba',
        :occurrences=> 'bac'
      }]
    ).must_equal(
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

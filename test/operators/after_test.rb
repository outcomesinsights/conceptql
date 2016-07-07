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
    )
  end

  it "should produce correct results when using :at_least option" do
    criteria_ids("after/crit_at_least",
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :at_least=>"15000d"}]
    )
  end

  it "should produce correct results when using :occurrences option" do
    criteria_ids("after/crit_occurrences",
      [:after,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}],
        :occurrences=>1}]
    )
  end

  it "should handle upstream errors when annotating" do
    annotate("after/anno_1",
      [:after,
       {:left=>"412",
        :right=>:time_window}]
    )

    annotate("after/anno_2",
      [:after,
       {:right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    )

    annotate("after/anno_3",
      [:after,
       {:left=>[:icd9, "412"]}]
    )

    annotate("after/anno_4",
      [:after,
       {:left=>[:union],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
    )

    annotate("after/anno_5",
      [:after,
       1,
       {:left=>[:icd9, "412"],
        :right=>[:time_window, [:gender, "Male"], {:start=>"50y", :end=>"50y"}]}]
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
    )
  end
end

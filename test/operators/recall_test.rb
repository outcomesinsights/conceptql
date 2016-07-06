require_relative '../helper'

describe ConceptQL::Operators::Recall do
  it "should raise error if attempting to execute invalid recall" do
    proc do
      criteria_ids("recall/raise_crit_1",
      ["after",
        {:left=>["during",
                 {:left=>["occurrence", 4, ["icd9", "203.0x", {"label"=>"Meyloma Dx"}]],
                  :right=>["time_window", ["first", ["recall", "Meyloma Dx"]], {"start"=>"0", "end"=>"90d"}]}],
         :right=>["union",
                  ["during",
                   {:left=>["time_window", ["recall", "Qualifying Meyloma Dx"], {"start"=>"-90d", "end"=>"0", "label"=>"Meyloma 90-day Lookback"}],
                    :right=>["cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275", "88291", "88305", {"label"=>"Bone Marrow"}]}],
                  ["occurrence", 2, ["during",
                                     {:left=>["cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", {"label"=>"Other Tests"}],
                                      :right=>["recall", "Meyloma 90-day Lookback"]}]]]}]
      )
    end.must_raise
  end

  it "should produce correct results" do
    criteria_ids("recall/crit_1",
      [:union,
        [:recall, 'label1'],
        [:one_in_two_out,
         [:icd9, '412'],
         label: 'label1']
      ]
    )

    criteria_ids("recall/crit_2", 
      [:union,
       ["icd9", "412", {"label": "Heart Attack"}],
       ["recall", "Heart Attack"]]
    )

    criteria_ids("recall/crit_3",
      [:except,
       {left: ["icd9", "412", {"label": "Heart Attack"}],
        right: [ "recall", "Heart Attack"]}]
    )
  end

  it "should have CTEs available no matter what order" do
    criteria_ids("recall/crit_cte_1",
      [:first,
        [
          :union,
          [:recall, "Codes"],
          [:icd9, "412", label: "Codes"]
        ]
      ]
    )
    criteria_ids("recall/crit_cte_2",
      [:first,
        [
          :union,
          [:icd9, "412", label: "Codes"],
          [:recall, "Codes"]
        ]
      ]
    )
  end

  it "should handle nested recall operators" do
    ops = [
      ["recall", "HA"],
      [:union,
       ["icd9", "412"],
       ["recall", "Heart Attack"],
       {"label": "HA"}],
      ["icd9",
       "412",
       {"label": "Heart Attack"}]]
    i = 0
    ops.permutation do |op|
      criteria_ids("recall/crit_nested_perm_#{i}",
        [:union, *op]
      )
    end
  end

  it "should handle errors when annotating" do
    annotate("recall/anno_1",
      [:except,
       {left: ["icd9", "412", {"label": 1}],
        right:[ "recall", "Heart Attack"]}]
    )

    annotate("recall/anno_2",
      [:union,
       ["icd9", "412", {"label": "Heart Attack"}],
       ["recall",
        "Heart Attack",
        ["icd9", "412"]]]
    )

    annotate("recall/anno_3",
      ["recall", "HA1"]
    )

    annotate("recall/anno_4",
      [:recall]
    )

    annotate("recall/anno_5",
      [:recall, "foo", "bar"]
    )

    annotate("recall/anno_6",
      ["after",
        {:left=>["during",
                 {:left=>["occurrence", 4, ["icd9", "203.0x", {"label"=>"Meyloma Dx"}]],
                  :right=>["time_window", ["first", ["recall", "Meyloma Dx"]], {"start"=>"0", "end"=>"90d"}]}],
         :right=>["union",
                  ["during",
                   {:left=>["time_window", ["recall", "Qualifying Meyloma Dx"], {"start"=>"-90d", "end"=>"0", "label"=>"Meyloma 90-day Lookback"}],
                    :right=>["cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275", "88291", "88305", {"label"=>"Bone Marrow"}]}],
                  ["occurrence", 2, ["during",
                                     {:left=>["cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", {"label"=>"Other Tests"}],
                                      :right=>["recall", "Meyloma 90-day Lookback"]}]]]}]
    )
  end
end

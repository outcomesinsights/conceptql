require_relative '../helper'

describe ConceptQL::Operators::Recall do
  it "should raise error if attempting to execute invalid recall" do
    proc do
      criteria_ids(
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
    criteria_ids(
      [:union,
        [:recall, 'label1'],
        [:one_in_two_out,
         [:icd9, '412'],
         label: 'label1']
      ]
    ).must_equal("condition_occurrence"=>[1829, 6083, 8618, 9882, 15149, 17774, 18412, 20005, 21619, 24437, 24707, 25309, 25888, 26766, 28188, 31542, 31877])

    criteria_ids(
      [:union,
       ["icd9", "412", {"label": "Heart Attack"}],
       ["recall", "Heart Attack"]]
    ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981])

    criteria_ids(
      [:except,
       {left: ["icd9", "412", {"label": "Heart Attack"}],
        right: [ "recall", "Heart Attack"]}]
    ).must_equal({})

    criteria_ids(
      [:first,
        [
          :union,
          [:icd9, "412", label: "Codes"],
          [:recall, "Codes"]
        ]
      ]
    ).must_equal({"condition_occurrence"=>[1712, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 18412, 18555, 19736, 20037, 21006, 21627, 22875, 22933, 24471, 24721, 24989, 25417, 25875, 26766, 27388, 28177, 30831, 31387, 31792, 32104, 32463, 32981]})
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
    ops.permutation do |op|
      criteria_ids(
        [:union, *op]
      ).must_equal("condition_occurrence"=>[1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981])
    end
  end

  it "should handle errors when annotating" do
    query(
      [:except,
       {left: ["icd9", "412", {"label": 1}],
        right:[ "recall", "Heart Attack"]}]
    ).annotate.must_equal(
      ["except",
       {:left=>["icd9", "412", {label: 1,
        :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["invalid label"]]}, :name=>"ICD-9 CM"}],
        :right=>["recall", "Heart Attack", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["no matching label", "Heart Attack"]]}}],
        :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}]
    )

    query(
      [:union,
       ["icd9", "412", {"label": "Heart Attack"}],
       ["recall",
        "Heart Attack",
        ["icd9", "412"]]]
    ).annotate.must_equal(
      ["union",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :label=>"Heart Attack", :name=>"ICD-9 CM"}],
       ["recall",
        ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}}, :name=>"ICD-9 CM"}],
        "Heart Attack",
        {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["has upstreams"]]}}],
      {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}]
    )

    query(
      ["recall", "HA1"]
    ).annotate.must_equal(
      ["recall", "HA1", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["no matching label", "HA1"]]}}]
    )

    query(
      [:recall]
    ).annotate.must_equal(
      ["recall", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["has no arguments"]]}}]
    )

    query(
      [:recall, "foo", "bar"]
    ).annotate.must_equal(
      ["recall", "foo", "bar", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["has multiple arguments"]]}}]
    )

    query(
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
    ).annotate.must_equal(
      ["after",
       {:left=>["during",
                {:left=>["occurrence", ["icd9", "203.0x", {:label=>"Meyloma Dx",
                                                           :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :warnings=>[["invalid source code", "203.0x"]]}, :name=>"ICD-9 CM"}], 4, {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}, :name=>"Nth Occurrence"}],
                :right=>["time_window",
                         ["first",
                          ["recall", "Meyloma Dx", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}],
                          {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}],
                         {:start=>"0", :end=>"90d", :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}], :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}],
       :right=>["union",
                ["during",
                 {:left=>["time_window",
                          ["recall", "Qualifying Meyloma Dx", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["no matching label", "Qualifying Meyloma Dx"]]}}],
                          {:start=>"-90d", :end=>"0", :label=>"Meyloma 90-day Lookback", :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}],
                  :right=>["cpt", "38220", "38221", "85102", "85095", "3155F", "85097", "88237", "88271", "88275", "88291", "88305", {:label=>"Bone Marrow", :annotation=>{:counts=>{:procedure_occurrence=>{:rows=>0, :n=>0}}}, :name=>"CPT"}], :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}],
                ["occurrence",
                 ["during", {:left=>["cpt", "84156", "84166", "86335", "84155", "84165", "86334", "83883", "81264", "82784", "82785", "82787", "82040", "82232", "77074", "77075", "83615", {:label=>"Other Tests", :annotation=>{:counts=>{:procedure_occurrence=>{:rows=>0, :n=>0}}}, :name=>"CPT"}],
                             :right=>["recall", "Meyloma 90-day Lookback", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}], :annotation=>{:counts=>{:procedure_occurrence=>{:rows=>0, :n=>0}}}}],
                 2,
                 {:annotation=>{:counts=>{:procedure_occurrence=>{:rows=>0, :n=>0}}}, :name=>"Nth Occurrence"}],
                {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}, :procedure_occurrence=>{:rows=>0, :n=>0}}}}],
       :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}]
    )
  end
end

require_relative '../helper'

describe ConceptQL::Operators::Recall do
  it "should produce correct results" do
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
        :right=>["recall", "Heart Attack", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}},:errors=>[["no matching label"]]}}],
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
      [:union,
       [:union, ["recall", "Heart Attack"]],
       {"label": "Heart Attack"}]
    ).annotate.must_equal(
      ["union",
       ["union",
        ["recall",
         "Heart Attack",
         {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["nested recall"]]}}],
        {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}],
       {:label=>"Heart Attack",
        :annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}]
    )

    query(
      [:union,
       [:union, ["recall", "HA1"], {"label": "HA2"}],
       [:union, ["recall", "HA2"], {"label": "HA1"}]]
    ).annotate.must_equal(
      ["union",
       ["recall", "HA2", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["mutually referential recalls", "HA1"]]}}],
       ["recall", "HA1", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["mutually referential recalls", "HA2"]]}}],
       {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}}}]
    )
    query(
      [:union,
       ["icd9", "412", {"label": "HA1"}],
       ["icd9", "409.1", {"label": "HA1"}]]
    ).annotate.must_equal(
      ["union",
       ["icd9", "412", {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>50, :n=>38}}},:label=>"HA1", :name=>"ICD-9 CM"}],
       ["icd9", "409.1", {:label=>"HA1",  :annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}, :errors=>[["duplicate label"]]}, :name=>"ICD-9 CM"}],
       {:annotation=>{:counts=>{:condition_occurrence=>{:rows=>0, :n=>0}}}}]
    )

    query(
      ["recall", "HA1"]
    ).annotate.must_equal(
      ["recall", "HA1", {:annotation=>{:counts=>{:invalid=>{:rows=>0, :n=>0}}, :errors=>[["no matching label"]]}}]
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
  end
end

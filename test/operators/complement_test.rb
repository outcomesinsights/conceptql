require_relative '../helper'

describe ConceptQL::Operators::Complement do
  it "should produce correct results" do
    # TODO this is more complex
    cids = criteria_ids("complement/crit_basic1",
      [:complement, [:icd9, "412"]]
    )["condition_occurrence"]
    cids.count.must_equal 33994
    [1712, 1829, 4359, 5751, 6083, 6902, 7865, 8397, 8618, 9882, 10196, 10443, 10865, 13016, 13741, 15149, 17041, 17772, 17774, 18412, 18555, 19736, 20005, 20037, 21006, 21619, 21627, 22875, 22933, 24437, 24471, 24707, 24721, 24989, 25309, 25417, 25875, 25888, 26766, 27388, 28177, 28188, 30831, 31387, 31542, 31792, 31877, 32104, 32463, 32981].each do |i|
      cids.wont_include(i)
    end

    criteria_ids("complement/crit_icd9_selector",
      [:complement, [:complement, [:icd9, "412"]]]
    )

    criteria_counts("complement/crit_union",
      [:complement, [:union, [:icd9, "412"], [:condition_type, :inpatient_header]]]
    )

    criteria_counts("complement/crit_intersect",
      [:intersect,
       [:complement, [:icd9, "412"]],
       [:complement, [:condition_type, :inpatient_header]]]
    )

    criteria_counts("complement/crit_3way_union",
      [:complement,
       [:union,
        [:icd9, "412"],
        [:condition_type, :inpatient_header],
        [:cpt, "99214"]]]
    )

    criteria_counts("complement/crit_3way_intersect",
      [:intersect,
       [:complement, [:icd9, "412"]],
       [:complement, [:condition_type, :inpatient_header]],
       [:complement, [:cpt, "99214"]]]
    )

    criteria_counts("complement/crit_union_and_intersect",
      [:union,
       [:intersect,
        [:complement, [:icd9, "412"]],
        [:complement, [:condition_type, :inpatient_header]]],
       [:complement, [:cpt, "99214"]]]
    )
  end

  it "should handle upstream errors in annotations" do
    annotate("complement/anno_no_params",
      [:complement]
    )

    annotate("complement/anno_duplicate_params",
      [:complement, [:icd9, "412"], [:icd9, "412"]]
    )

    annotate("complement/anno_invalid_params",
      [:complement, "412", [:icd9, "412"]]
    )
  end
end


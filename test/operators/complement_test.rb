require_relative '../helper'

describe ConceptQL::Operators::Complement do
  it "should produce correct results" do
    criteria_ids("complement/crit_basic1",
      [:complement, [:icd9, "412"]]
    )

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


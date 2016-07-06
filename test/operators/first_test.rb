require_relative '../helper'

describe ConceptQL::Operators::First do
  it "should produce correct results" do
    criteria_ids("first/crit_icd9",
      [:first, [:icd9, "412"]]
    )

    criteria_ids("first/crit_cpt",
      [:first, [:cpt, "99214"]]
    )

    criteria_ids("first/crit_union",
      [:first, [:union, [:icd9, "412"], [:death, true]]]
    )
  end

  it "should handle errors when annotating" do
    annotate("first/crit_no_upstream",
      [:first]
    )

    annotate("first/crit_argument",
      [:first, 1]
    )
  end
end


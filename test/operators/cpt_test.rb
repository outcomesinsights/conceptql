require_relative '../helper'

describe ConceptQL::Operators::Cpt do
  it "should produce correct results" do
    criteria_counts("cpt/crit_1",
      [:cpt, "99214"]
    )

    criteria_ids("cpt/crit_2",
      [:cpt, "99215"]
    )
  end

  it "should handle errors when annotating" do
    annotate("cpt/anno_icd9_upstream",
      [:cpt, [:icd9, "412"]]
    )

    annotate("cpt/anno_invalid_code",
      [:cpt, "99214", "XYS"]
    )
  end

  it "should show operators when annotating" do
    scope_annotate("cpt/scanno_1",
      [:cpt, "99214"]
    )
  end
end

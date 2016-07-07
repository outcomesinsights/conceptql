require_relative '../helper'

describe ConceptQL::Operators::Count do
  it "should produce correct results" do
    criteria_ids("count/crit_ndc",
      [:count, [:numeric, 1, [:ndc, "12745010902"]]]
    )

    criteria_ids("count/crit_icd9_ndc",
      [:count, [:icd9_procedure, "00.13"], [:numeric, 1, [:ndc, "12745010902"]]]
    )

    criteria_ids("count/crit_person",
      [:count, [:numeric, 1]]
    )
  end

  it "should handle errors when annotating" do
    annotate("count/anno_no_upstream1",
      [:count]
    )

    annotate("count/anno_no_upstream2",
      [:count, 1]
    )

    annotate("count/anno_multiple_upstreams",
      [:count, [:icd9, "412"], [:icd9, "401.9"]]
    )
  end
end



require_relative '../helper'

describe ConceptQL::Operators::Death do
  it "should produce correct results" do
    criteria_ids("death/crit_basic",
      [:death]
    )

    criteria_ids("death/crit_person",
      [:death, [:person, true]]
    )
  end

  it "should handle errors when annotating" do
    annotate("death/anno_multiple_upstreams",
      [:death, [:person], [:icd9, "412"]]
    )

    annotate("death/anno_no_upstreams",
      [:death, "412"]
    )
  end
end

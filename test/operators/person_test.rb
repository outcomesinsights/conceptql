require_relative '../helper'

describe ConceptQL::Operators::Person do
  it "should produce correct results" do
    criteria_ids("person/crit_1",
      [:person, [:icd9, "412"]]
    )

    criteria_counts("person/crit_2",
      [:person]
    )
  end

  it "should handle errors when annotating" do
    annotate("person/anno_multiple_upstreams",
      [:person, [:icd9, "412"], [:icd9, "412"]]
    )

    annotate("person/anno_has_arguments",
      [:person, "412"]
    )
  end
end

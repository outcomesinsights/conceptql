require_relative '../helper'

describe ConceptQL::Operators::From do
  it "should produce correct results" do
    criteria_counts("from/count_person",
      [:from, 'person']
    )

    criteria_counts("from/count_observation_period",
      [:from, 'observation_period']
    )

    criteria_counts("from/count_condition_occurrence",
      [:from, 'condition_occurrence']
    )
  end

  it "should handle errors when annotating" do
    annotate("from/anno_has_upstreams",
      [:from, [:icd9, "412"]]
    )

    annotate("from/anno_multiple_arguments",
      [:from, 'person', 'observation_period']
    )
  end
end

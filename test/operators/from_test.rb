require_relative '../helper'

describe ConceptQL::Operators::From do
  it "should produce correct results" do
    count("from/count_person",
      [:from, 'person']
    )

    count("from/count_observation_period",
      [:from, 'observation_period']
    )

    count("from/count_condition_occurrence",
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

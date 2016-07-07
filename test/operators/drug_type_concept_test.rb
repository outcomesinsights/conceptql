require_relative '../helper'

describe ConceptQL::Operators::DrugTypeConcept do
  it "should produce correct results" do
    criteria_ids("drug_type_concept/crit_basic1",
      [:drug_type_concept, 2]
    )

    criteria_ids("drug_type_concept/crit_basic2",
      [:drug_type_concept, 1]
    )
  end

  it "should handle errors when annotating" do
    annotate("drug_type_concept/anno_has_upstreams",
      [:drug_type_concept, 2, [:icd9, "412"]]
    )

    annotate("drug_type_concept/anno_no_arguments",
      [:drug_type_concept]
    )
  end
end

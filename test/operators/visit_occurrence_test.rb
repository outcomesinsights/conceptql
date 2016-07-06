require_relative '../helper'

describe ConceptQL::Operators::VisitOccurrence do
  it "should produce correct results" do
    criteria_ids("visit_occurrence/crit_1",
      [:visit_occurrence, [:icd9, "412"]]
    )

    criteria_ids("visit_occurrence/crit_2",
      [:visit_occurrence, [:gender, "Male"]]
    )

    criteria_ids("visit_occurrence/crit_3",
      [:visit_occurrence]
    )
  end

  it "should handle errors when annotating" do
    annotate("visit_occurrence/anno_1",
      [:visit_occurrence, [:icd9, "412"], [:icd9, "412"]]
    )

    annotate("visit_occurrence/anno_2",
      [:visit_occurrence, 21, [:icd9, "412"]]
    )
  end
end

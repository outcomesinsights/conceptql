require_relative '../helper'

describe ConceptQL::Operators::FromSeerVisits do
  it "should produce correct results" do
    criteria_ids("from_seer_visits/crit_1",
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1, 2])

    criteria_ids("from_seer_visits/crit_2",
      [:from_seer_visits, "Doctor", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1])

    criteria_ids("from_seer_visits/crit_3",
      [:from_seer_visits, "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[2])

    criteria_ids("from_seer_visits/crit_4",
      [:from_seer_visits, "Doctor", "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1,2])
  end

  it "should handle errors when annotating" do
    annotate("from_seer_visits/anno_no_upstream",
      [:from_seer_visits]
    )

    annotate("from_seer_visits/multiple_upstreams",
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]], [:visit_occurrence, [:icd9, "412"]]]
    )
  end
end

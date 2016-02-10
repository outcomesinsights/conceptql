require_relative '../helper'

describe ConceptQL::Operators::FromSeerVisits do
  it "should produce correct results" do
    criteria_ids(
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1, 2])

    criteria_ids(
      [:from_seer_visits, "Doctor", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1])

    criteria_ids(
      [:from_seer_visits, "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[2])

    criteria_ids(
      [:from_seer_visits, "Doctor", "Nurse", [:visit_occurrence, [:icd9, "412"]]]
    ).must_equal("observation"=>[1,2])
  end

  it "should handle errors when annotating" do
    query(
      [:from_seer_visits]
    ).annotate.must_equal(
      ["from_seer_visits", {:annotation=>{:errors=>[["has no upstream"]]}}]
    )

    query(
      [:from_seer_visits, [:visit_occurrence, [:icd9, "412"]], [:visit_occurrence, [:icd9, "412"]]]
    ).annotate.must_equal(
      ["from_seer_visits",
       ["visit_occurrence",
        ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
        {:annotation=>{:visit_occurrence=>{:rows=>50, :n=>38}}}],
       ["visit_occurrence",
        ["icd9", "412", {:annotation=>{:condition_occurrence=>{:rows=>50, :n=>38}}, :name=>"ICD-9 CM"}],
        {:annotation=>{:visit_occurrence=>{:rows=>50, :n=>38}}}],
       {:annotation=>{:errors=>[["has multiple upstreams"]]}}]
    )
  end
end
